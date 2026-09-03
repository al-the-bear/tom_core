import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'info_panel.dart';

/// Row controls for authorization manipulation (Demo B).
///
/// The panel is **stateless** — the parent demo owns the actual state
/// (adapter rules, group mode, authorizer/UI-state toggles) and passes the
/// current values in. Callbacks let the panel propagate user input.
class AuthControlPanel extends StatelessWidget {
  /// Current form-level auth state (shown in the first dropdown).
  final TomAuthState formAuth;
  final ValueChanged<TomAuthState> onFormAuthChanged;

  /// Name of each group the user can select (IDs are display-friendly).
  final List<String> groupIds;

  /// Currently selected group id (index into [groupIds]).
  final String selectedGroupId;
  final ValueChanged<String> onGroupSelected;

  /// Mode of the currently selected group.
  final AuthGroupMode groupMode;
  final ValueChanged<AuthGroupMode> onGroupModeChanged;

  /// Path → current auth for every per-field override control.
  final Map<String, TomAuthState> fieldOverrides;

  /// Callback when the user toggles a per-field override. When the new state
  /// equals [TomAuthState.full] the parent should typically clear the rule
  /// so the path falls through to its natural auth.
  final void Function(String path, TomAuthState state) onFieldOverrideChanged;

  /// Whether a global `TomAuthorizer` is attached.
  final bool authorizerEnabled;
  final ValueChanged<bool> onAuthorizerToggled;

  /// Whether a global `TomUIStateController` is attached.
  final bool uiStateControllerEnabled;
  final ValueChanged<bool> onUIStateControllerToggled;

  const AuthControlPanel({
    super.key,
    required this.formAuth,
    required this.onFormAuthChanged,
    required this.groupIds,
    required this.selectedGroupId,
    required this.onGroupSelected,
    required this.groupMode,
    required this.onGroupModeChanged,
    required this.fieldOverrides,
    required this.onFieldOverrideChanged,
    required this.authorizerEnabled,
    required this.onAuthorizerToggled,
    required this.uiStateControllerEnabled,
    required this.onUIStateControllerToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const InfoPanelHeading('Form-level auth'),
        _buildAuthDropdown(context, formAuth, onFormAuthChanged),
        const InfoPanelHeading('Group'),
        _buildGroupSelector(context),
        const SizedBox(height: 4),
        _buildGroupModeToggle(context),
        const InfoPanelHeading('Per-field overrides'),
        ..._buildFieldOverrides(context),
        const InfoPanelHeading('Authorizer / UI-state controller'),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('TomAuthorizer (finalizedOrders → read-only)'),
          subtitle: const Text(
            'When on, billing & shipping narrow to read if the customer tier is platinum.',
            style: TextStyle(fontSize: 11),
          ),
          value: authorizerEnabled,
          onChanged: onAuthorizerToggled,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('TomUIStateController (data-dependent)'),
          subtitle: const Text(
            'When on, disables the email field while "phone" is empty.',
            style: TextStyle(fontSize: 11),
          ),
          value: uiStateControllerEnabled,
          onChanged: onUIStateControllerToggled,
        ),
      ],
    );
  }

  Widget _buildAuthDropdown(
    BuildContext context,
    TomAuthState current,
    ValueChanged<TomAuthState> onChanged,
  ) {
    return DropdownButton<TomAuthState>(
      isExpanded: true,
      value: current,
      items: TomAuthState.values
          .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildGroupSelector(BuildContext context) {
    return DropdownButton<String>(
      isExpanded: true,
      value: selectedGroupId,
      items: groupIds
          .map((id) => DropdownMenuItem(value: id, child: Text(id)))
          .toList(),
      onChanged: (v) {
        if (v != null) onGroupSelected(v);
      },
    );
  }

  Widget _buildGroupModeToggle(BuildContext context) {
    return SegmentedButton<AuthGroupMode>(
      segments: const [
        ButtonSegment(
          value: AuthGroupMode.controlsAll,
          label: Text('controlsAll'),
        ),
        ButtonSegment(
          value: AuthGroupMode.controlsWidest,
          label: Text('controlsWidest'),
        ),
        ButtonSegment(
          value: AuthGroupMode.controlsNarrowest,
          label: Text('controlsNarrowest'),
        ),
      ],
      selected: {groupMode},
      onSelectionChanged: (s) => onGroupModeChanged(s.first),
      showSelectedIcon: false,
    );
  }

  List<Widget> _buildFieldOverrides(BuildContext context) {
    if (fieldOverrides.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '(no per-field overrides configured)',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      ];
    }
    // Stack the label above the dropdown so the full basePath is always
    // readable — a Row with a fixed-width label ellipsises common paths
    // like `demoB.customer.customerTier` into uselessness.
    return [
      for (final entry in fieldOverrides.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                entry.key,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
              _buildAuthDropdown(
                context,
                entry.value,
                (v) => onFieldOverrideChanged(entry.key, v),
              ),
            ],
          ),
        ),
    ];
  }
}
