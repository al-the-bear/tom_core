/// Demo 28: Authorization
///
/// Demonstrates the Tom UI authorization system. Shows how widgets can be
/// hidden or made readonly based on authorization state, how [TomUIGroup]
/// controls collective visibility, and how [TomUIAuthorization] resolves
/// auth state from resource paths.
///
/// Key concepts:
/// - Per-widget visibility/readonly via [TomUIAuthorization]
/// - Group-based visibility via [TomUIGroup]
/// - Authorization with scoped providers
/// - Readonly styling applied by [TomThemeScope]
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Custom Authorization Adapter for the Demo
// =============================================================================

/// Demo adapter that allows toggling authorization state at runtime.
class DemoAuthorizationAdapter implements TomUIAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};

  void setRule(String path, TomAuthState state) {
    _rules[path] = state;
  }

  void removeRule(String path) {
    _rules.remove(path);
  }

  void clearRules() {
    _rules.clear();
  }

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    // Check exact match first
    if (_rules.containsKey(resourceKeyPath)) {
      return _rules[resourceKeyPath]!;
    }
    // Check parent paths (e.g., "demo28.admin" matches "demo28.admin.delete")
    final parts = resourceKeyPath.split('.');
    for (int i = parts.length - 1; i > 0; i--) {
      final parentPath = parts.sublist(0, i).join('.');
      if (_rules.containsKey(parentPath)) {
        return _rules[parentPath]!;
      }
    }
    return TomAuthState.fullAccess;
  }
}

// =============================================================================
// Element Providers
// =============================================================================

/// Provider for admin-level actions.
///
/// Scope path: demo28.admin
class AdminSectionProvider extends TomScreenElementsProviderBase {
  AdminSectionProvider() : super('admin');

  late final viewButton = TomElevatedButton(
    tomId: 'view',
    scope: this,
    onPressed: () {},
  );

  late final editButton = TomElevatedButton(
    tomId: 'edit',
    scope: this,
    onPressed: () {},
  );

  late final deleteButton = TomElevatedButton(
    tomId: 'delete',
    scope: this,
    onPressed: () {},
  );
}

/// Provider for grouped widgets.
///
/// Scope path: demo28.grouped
class GroupedSectionProvider extends TomScreenElementsProviderBase {
  GroupedSectionProvider() : super('grouped');

  final premiumGroup = TomUIGroup('premium');
  final basicGroup = TomUIGroup('basic');

  late final premiumFeature1 = TomChip(
    tomId: 'premium1',
    scope: this,
    tomGroup: premiumGroup,
  );

  late final premiumFeature2 = TomChip(
    tomId: 'premium2',
    scope: this,
    tomGroup: premiumGroup,
  );

  late final basicFeature1 = TomChip(
    tomId: 'basic1',
    scope: this,
    tomGroup: basicGroup,
  );

  late final basicFeature2 = TomChip(
    tomId: 'basic2',
    scope: this,
    tomGroup: basicGroup,
  );
}

/// Provider for readonly demonstration.
///
/// Scope path: demo28.profile
class ProfileSectionProvider extends TomScreenElementsProviderBase {
  ProfileSectionProvider() : super('profile');

  late final nameField = TomTextField(
    tomId: 'name',
    scope: this,
  );

  late final emailField = TomTextField(
    tomId: 'email',
    scope: this,
  );

  late final roleField = TomTextField(
    tomId: 'role',
    scope: this,
  );

  late final saveButton = TomElevatedButton(
    tomId: 'save',
    scope: this,
    onPressed: () {},
  );
}

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Authorization demo.
class AuthorizationDemo extends TomStatelessWidget {
  AuthorizationDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _AuthorizationDemoContent();
  }
}

class _AuthorizationDemoContent extends TomStatefulWidget {
  _AuthorizationDemoContent();

  @override
  State<_AuthorizationDemoContent> createState() =>
      _AuthorizationDemoContentState();
}

class _AuthorizationDemoContentState
    extends TomState<_AuthorizationDemoContent> {
  final _authAdapter = DemoAuthorizationAdapter();
  late AdminSectionProvider _adminProvider = AdminSectionProvider();
  late GroupedSectionProvider _groupedProvider = GroupedSectionProvider();
  late ProfileSectionProvider _profileProvider = ProfileSectionProvider();

  // UI state for toggle controls
  bool _deleteHidden = false;
  bool _editReadonly = false;
  bool _profileReadonly = false;
  bool _profileHidden = false;
  bool _premiumHidden = false;

  @override
  void initState() {
    super.initState();
    // Install our demo adapter
    TomUIAuthorization.adapter = _authAdapter;
  }

  /// Recreates all providers and widgets from scratch.
  void _applyFromScratch() {
    setState(() {
      _adminProvider = AdminSectionProvider();
      _groupedProvider = GroupedSectionProvider();
      _profileProvider = ProfileSectionProvider();
    });
  }

  void _updateAuthRules() {
    _authAdapter.clearRules();

    if (_deleteHidden) {
      _authAdapter.setRule('demo28.admin.delete', TomAuthState.hidden);
    }
    if (_editReadonly) {
      _authAdapter.setRule('demo28.admin.edit', TomAuthState.readOnly);
    }
    if (_profileReadonly) {
      _authAdapter.setRule('demo28.profile', TomAuthState.readOnly);
    }
    if (_profileHidden) {
      _authAdapter.setRule('demo28.profile', TomAuthState.hidden);
    }
    if (_premiumHidden) {
      _authAdapter.setRule('demo28.grouped.premium', TomAuthState.hidden);
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    // Apply auth rules before building
    _updateAuthRules();

    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Apply button — rebuilds all providers from scratch
            Align(
              alignment: Alignment.centerRight,
              child: TomElevatedButton(
                tomId: 'apply',
                onPressed: _applyFromScratch,
              ),
            ),
            TomSizedBox(height: 16),

            // Section 1: Authorization Controls
            _SectionHeader(tomId: 'section.controls'),
            TomSizedBox(height: 16),
            _buildControlPanel(),
            TomSizedBox(height: 32),

            // Section 2: Per-Widget Authorization
            _SectionHeader(tomId: 'section.perWidget'),
            TomSizedBox(height: 16),
            _buildPerWidgetDemo(),
            TomSizedBox(height: 32),

            // Section 3: Group Authorization
            _SectionHeader(tomId: 'section.groups'),
            TomSizedBox(height: 16),
            _buildGroupDemo(),
            TomSizedBox(height: 32),

            // Section 4: Section-Level Authorization
            _SectionHeader(tomId: 'section.sectionLevel'),
            TomSizedBox(height: 16),
            _buildSectionLevelDemo(context),
            TomSizedBox(height: 32),

            // Section 5: Auth State Visualization
            _SectionHeader(tomId: 'section.states'),
            TomSizedBox(height: 16),
            _buildAuthStateVisualization(context),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return _DemoCard(
      tomId: 'card.controls',
      child: TomColumn(
        children: [
          _buildToggleRow(
            'Hide delete button',
            'demo28.admin.delete → hidden',
            _deleteHidden,
            (v) => setState(() => _deleteHidden = v),
          ),
          _buildToggleRow(
            'Make edit readonly',
            'demo28.admin.edit → readonly',
            _editReadonly,
            (v) => setState(() => _editReadonly = v),
          ),
          TomDivider(),
          _buildToggleRow(
            'Hide premium features',
            'demo28.grouped.premium → hidden',
            _premiumHidden,
            (v) => setState(() => _premiumHidden = v),
          ),
          TomDivider(),
          _buildToggleRow(
            'Profile section readonly',
            'demo28.profile → readonly (all children)',
            _profileReadonly,
            (v) => setState(() {
              _profileReadonly = v;
              if (v) _profileHidden = false;
            }),
          ),
          _buildToggleRow(
            'Profile section hidden',
            'demo28.profile → hidden (all children)',
            _profileHidden,
            (v) => setState(() {
              _profileHidden = v;
              if (v) _profileReadonly = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String label,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return TomPadding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TomRow(
        children: [
          TomExpanded(
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildPerWidgetDemo() {
    return _DemoCard(
      tomId: 'card.perWidget',
      child: TomRow(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _adminProvider.viewButton,
          _adminProvider.editButton,
          _adminProvider.deleteButton,
        ],
      ),
    );
  }

  Widget _buildGroupDemo() {
    return _DemoCard(
      tomId: 'card.groups',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Features',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _groupedProvider.premiumFeature1,
              _groupedProvider.premiumFeature2,
            ],
          ),
          TomSizedBox(height: 16),
          Text(
            'Basic Features',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          TomSizedBox(height: 8),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _groupedProvider.basicFeature1,
              _groupedProvider.basicFeature2,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLevelDemo(BuildContext context) {
    return _DemoCard(
      tomId: 'card.sectionLevel',
      child: TomAclBuilder<ProfileSectionProvider>(
        id: 'profileAcl',
        elementProvider: _profileProvider,
        title: 'User Profile',
      )
          .append((p) => p.nameField)
          .append((p) => p.emailField)
          .newRow()
          .append((p) => p.roleField)
          .newRow()
          .gapRow()
          .newRow()
          .gap()
          .append((p) => p.saveButton)
          .build(context),
    );
  }

  Widget _buildAuthStateVisualization(BuildContext context) {
    final theme = Theme.of(context);
    final paths = [
      'demo28.admin.view',
      'demo28.admin.edit',
      'demo28.admin.delete',
      'demo28.grouped.premium',
      'demo28.grouped.basic',
      'demo28.profile',
      'demo28.profile.name',
      'demo28.profile.save',
    ];

    return _DemoCard(
      tomId: 'card.states',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final path in paths) ...[
            Builder(builder: (context) {
              final auth = TomUIAuthorization.resolveAuth(path);
              final stateLabel = !auth.visible
                  ? 'HIDDEN'
                  : auth.readonly
                      ? 'READONLY'
                      : 'FULL ACCESS';
              final stateColor = !auth.visible
                  ? Colors.red
                  : auth.readonly
                      ? Colors.orange
                      : Colors.green;

              return TomPadding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: TomRow(
                  children: [
                    TomSizedBox(
                      width: 200,
                      child: Text(
                        path,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    TomContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: stateColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        stateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: stateColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Shared Widgets
// =============================================================================

class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({required this.tomId});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(
          tomId: '$tomId.title',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TomSizedBox(height: 8),
        TomContainer(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: tomId),
                TomSizedBox(width: 12),
                TomExpanded(
                  child: TomText(
                    tomId: '$tomId.title',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 8),
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
