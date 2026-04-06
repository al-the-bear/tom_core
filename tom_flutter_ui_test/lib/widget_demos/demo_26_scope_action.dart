/// Demo 26: Scope & Action
///
/// Demonstrates [TomScreenElementsProviderBase] for building reusable,
/// scoped widget trees. Widgets are created once and returned on every
/// rebuild. Nesting providers chains scopes automatically.
///
/// Key concepts:
/// - Provider-based widget construction outside `build()`
/// - Hierarchical scope nesting with automatic resource paths
/// - Using providers with [TomAclBuilder]
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Element Providers
// =============================================================================

/// Root provider for the entire demo.
///
/// Uses the zone scope (demo26) set by the demo framework — no sub-scope.
class Demo26Provider extends TomScreenElementsProviderBase {
  Demo26Provider();

  /// Nested sub-provider: demo26.basic
  late final basic = BasicSectionProvider(this);

  /// Nested sub-provider: demo26.actions
  late final actions = ActionsSectionProvider(this);

  /// Nested sub-provider: demo26.composite
  late final composite = CompositeSectionProvider(this);
}

/// Provider for the "basic" section.
///
/// Scope path: demo26.basic
class BasicSectionProvider extends TomScreenElementsProviderBase {
  BasicSectionProvider(TomScreenElementsProvider parent)
      : super('basic', parent);

  late final title = TomText(
    tomId: 'title',
    scope: this,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );

  late final description = TomText(
    tomId: 'description',
    scope: this,
  );

  late final actionButton = TomElevatedButton(
    tomId: 'action',
    scope: this,
    onPressed: () {},
  );

  late final infoButton = TomOutlinedButton(
    tomId: 'info',
    scope: this,
    onPressed: () {},
  );

  /// Nested sub-provider: demo26.basic.details
  late final details = DetailsSectionProvider(this);
}

/// Provider demonstrating nesting: a sub-section inside the basic section.
///
/// Scope path: demo26.basic.details
class DetailsSectionProvider extends TomScreenElementsProviderBase {
  DetailsSectionProvider(TomScreenElementsProvider parent)
      : super('details', parent);

  late final label = TomText(
    tomId: 'label',
    scope: this,
  );

  late final statusChip = TomChip(
    tomId: 'status',
    scope: this,
  );

  late final editButton = TomTextButton(
    tomId: 'edit',
    scope: this,
    onPressed: () {},
  );

  /// Nested sub-provider: demo26.basic.details.metadata
  late final metadata = MetadataSectionProvider(this);
}

/// Provider with deeper nesting to show 3-level scope chains.
///
/// Scope path: demo26.basic.details.metadata
class MetadataSectionProvider extends TomScreenElementsProviderBase {
  MetadataSectionProvider(TomScreenElementsProvider parent)
      : super('metadata', parent);

  late final createdLabel = TomText(
    tomId: 'created',
    scope: this,
  );

  late final modifiedLabel = TomText(
    tomId: 'modified',
    scope: this,
  );
}

/// Provider for the "actions" section.
///
/// Scope path: demo26.actions
class ActionsSectionProvider extends TomScreenElementsProviderBase {
  ActionsSectionProvider(TomScreenElementsProvider parent)
      : super('actions', parent);

  late final saveButton = TomElevatedButton(
    tomId: 'save',
    scope: this,
    onPressed: () {},
  );

  late final cancelButton = TomOutlinedButton(
    tomId: 'cancel',
    scope: this,
    onPressed: () {},
  );

  late final deleteButton = TomTextButton(
    tomId: 'delete',
    scope: this,
    onPressed: () {},
  );
}

/// Provider that composes its own nested sub-providers as fields.
///
/// Scope path: demo26.composite
class CompositeSectionProvider extends TomScreenElementsProviderBase {
  CompositeSectionProvider(TomScreenElementsProvider parent)
      : super('composite', parent);

  late final header = TomText(
    tomId: 'header',
    scope: this,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  /// Nested sub-provider: demo26.composite.address
  late final address = AddressSubProvider(this);

  /// Nested sub-provider: demo26.composite.contact
  late final contact = ContactSubProvider(this);
}

/// Sub-provider: demo26.composite.address
class AddressSubProvider extends TomScreenElementsProviderBase {
  AddressSubProvider(TomScreenElementsProvider parent)
      : super('address', parent);

  late final streetField = TomTextField(
    tomId: 'street',
    scope: this,
  );

  late final cityField = TomTextField(
    tomId: 'city',
    scope: this,
  );
}

/// Sub-provider: demo26.composite.contact
class ContactSubProvider extends TomScreenElementsProviderBase {
  ContactSubProvider(TomScreenElementsProvider parent)
      : super('contact', parent);

  late final emailField = TomTextField(
    tomId: 'email',
    scope: this,
  );

  late final phoneField = TomTextField(
    tomId: 'phone',
    scope: this,
  );
}

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Scope & Action demo.
class ScopeActionDemo extends TomStatelessWidget {
  ScopeActionDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ScopeActionDemoContent();
  }
}

class _ScopeActionDemoContent extends TomStatefulWidget {
  _ScopeActionDemoContent();

  @override
  State<_ScopeActionDemoContent> createState() =>
      _ScopeActionDemoContentState();
}

class _ScopeActionDemoContentState
    extends TomState<_ScopeActionDemoContent> {
  // Single root provider — all sections nested as fields.
  // Non-final so the "Apply" button can recreate everything from scratch.
  late Demo26Provider demo26 = Demo26Provider();

  /// Recreates all providers and widgets from scratch.
  void _applyFromScratch() {
    setState(() {
      demo26 = Demo26Provider();
    });
  }

  @override
  Widget buildContent(BuildContext context) {
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

            // Section 1: Basic Provider
            _SectionHeader(tomId: 'section.basic'),
            TomSizedBox(height: 16),
            _buildBasicProviderDemo(),
            TomSizedBox(height: 32),

            // Section 2: Nested Scope Chains
            _SectionHeader(tomId: 'section.nested'),
            TomSizedBox(height: 16),
            _buildNestedScopeDemo(),
            TomSizedBox(height: 32),

            // Section 3: Actions Provider (zone scope)
            _SectionHeader(tomId: 'section.actions'),
            TomSizedBox(height: 16),
            _buildActionsDemo(),
            TomSizedBox(height: 32),

            // Section 4: Composite Provider with ACL
            _SectionHeader(tomId: 'section.composite'),
            TomSizedBox(height: 16),
            _buildCompositeAclDemo(context),
            TomSizedBox(height: 32),

            // Section 5: Scope Path Visualization
            _SectionHeader(tomId: 'section.paths'),
            TomSizedBox(height: 16),
            _buildScopePathVisualization(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicProviderDemo() {
    return _DemoCard(
      tomId: 'card.basicProvider',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          demo26.basic.title,
          TomSizedBox(height: 8),
          demo26.basic.description,
          TomSizedBox(height: 16),
          TomRow(
            children: [
              demo26.basic.actionButton,
              TomSizedBox(width: 12),
              demo26.basic.infoButton,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNestedScopeDemo() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level 1: basic
        _DemoCard(
          tomId: 'card.nested1',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              demo26.basic.title,
              TomSizedBox(height: 8),
              demo26.basic.description,
            ],
          ),
        ),
        // Level 2: basic.details
        TomPadding(
          padding: const EdgeInsets.only(left: 24),
          child: _DemoCard(
            tomId: 'card.nested2',
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                demo26.basic.details.label,
                TomSizedBox(height: 8),
                demo26.basic.details.statusChip,
                TomSizedBox(height: 8),
                demo26.basic.details.editButton,
              ],
            ),
          ),
        ),
        // Level 3: basic.details.metadata
        TomPadding(
          padding: const EdgeInsets.only(left: 48),
          child: _DemoCard(
            tomId: 'card.nested3',
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                demo26.basic.details.metadata.createdLabel,
                TomSizedBox(height: 4),
                demo26.basic.details.metadata.modifiedLabel,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsDemo() {
    return _DemoCard(
      tomId: 'card.actions',
      child: TomRow(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          demo26.actions.deleteButton,
          const Spacer(),
          demo26.actions.cancelButton,
          TomSizedBox(width: 12),
          demo26.actions.saveButton,
        ],
      ),
    );
  }

  Widget _buildCompositeAclDemo(BuildContext context) {
    return _DemoCard(
      tomId: 'card.composite',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          demo26.composite.header,
          TomSizedBox(height: 16),
          // Address sub-section via TomAclBuilder
          TomAclBuilder<AddressSubProvider>(
            id: 'addressAcl',
            elementProvider: demo26.composite.address,
            title: 'Address',
          )
              .append((p) => p.streetField)
              .newRow()
              .append((p) => p.cityField)
              .build(context),
          TomSizedBox(height: 16),
          // Contact sub-section via TomAclBuilder
          TomAclBuilder<ContactSubProvider>(
            id: 'contactAcl',
            elementProvider: demo26.composite.contact,
            title: 'Contact',
          )
              .append((p) => p.emailField)
              .newRow()
              .append((p) => p.phoneField)
              .build(context),
        ],
      ),
    );
  }

  Widget _buildScopePathVisualization(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <(String, String)>[
      ('Demo26Provider', demo26.getScopePath()),
      ('BasicSectionProvider', demo26.basic.getScopePath()),
      ('DetailsSectionProvider', demo26.basic.details.getScopePath()),
      ('MetadataSectionProvider',
          demo26.basic.details.metadata.getScopePath()),
      ('ActionsSectionProvider', demo26.actions.getScopePath()),
      ('CompositeSectionProvider', demo26.composite.getScopePath()),
      ('AddressSubProvider', demo26.composite.address.getScopePath()),
      ('ContactSubProvider', demo26.composite.contact.getScopePath()),
    ];

    return _DemoCard(
      tomId: 'card.paths',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, path) in entries) ...[
            TomRow(
              children: [
                TomSizedBox(
                  width: 220,
                  child: Text(
                    name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TomIcon(icon: Icons.arrow_forward, size: 16),
                TomSizedBox(width: 8),
                TomExpanded(
                  child: TomContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      path,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 4),
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
