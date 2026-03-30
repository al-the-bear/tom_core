/// Demo 21: Resource Resolution
///
/// Comprehensive demonstration of the Tom UI resource resolution system.
/// This demo shows how widgets resolve all their parameters (labels, icons,
/// tooltips, hints, colors, sizes, etc.) from resources using tomId lookup
/// instead of hardcoding values.
///
/// Widgets covered: TomText, TomIcon, TomElevatedButton, TomFilledButton,
/// TomTextField, TomBadge, TomCard, TomListTile, TomTooltip, TomIconButton,
/// TomExpansionTile, TomBanner.
///
/// Resource suffixes demonstrated:
/// - Text: label, title, subtitle, description, hint, helper, message
/// - Icons: icon, alt
/// - Interactive: tooltip
/// - Validation: errorFormat, errorInvalid
/// - Numeric: size, fill, weight, grade, opticalSize
/// - Colors: color (as named color strings)
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Resource Resolution demo.
class ResourceResolutionDemo extends StatelessWidget {
  const ResourceResolutionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ResourceResolutionDemoContent();
  }
}

class _ResourceResolutionDemoContent extends StatefulWidget {
  const _ResourceResolutionDemoContent();

  @override
  State<_ResourceResolutionDemoContent> createState() =>
      _ResourceResolutionDemoContentState();
}

class _ResourceResolutionDemoContentState
    extends State<_ResourceResolutionDemoContent> {
  // State for interactive demos
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _SectionHeader(tomId: 'demo21.section.intro'),
            const TomSizedBox(height: 16),
            _buildIntroductionSection(),
            const TomSizedBox(height: 32),

            // Section 1: Text Resources (label, title, subtitle, description)
            _SectionHeader(tomId: 'demo21.section.text'),
            const TomSizedBox(height: 16),
            _buildTextResourcesSection(),
            const TomSizedBox(height: 32),

            // Section 2: Icon Resources (icon, alt, size, color)
            _SectionHeader(tomId: 'demo21.section.icons'),
            const TomSizedBox(height: 16),
            _buildIconResourcesSection(),
            const TomSizedBox(height: 32),

            // Section 3: Button Resources (label, icon, tooltip)
            _SectionHeader(tomId: 'demo21.section.buttons'),
            const TomSizedBox(height: 16),
            _buildButtonResourcesSection(),
            const TomSizedBox(height: 32),

            // Section 4: Input Resources (hint, helper, errorFormat)
            _SectionHeader(tomId: 'demo21.section.inputs'),
            const TomSizedBox(height: 16),
            _buildInputResourcesSection(),
            const TomSizedBox(height: 32),

            // Section 5: List & Tile Resources (title, subtitle, leading)
            _SectionHeader(tomId: 'demo21.section.lists'),
            const TomSizedBox(height: 16),
            _buildListResourcesSection(),
            const TomSizedBox(height: 32),

            // Section 6: Interactive Resources (tooltip, message)
            _SectionHeader(tomId: 'demo21.section.interactive'),
            const TomSizedBox(height: 16),
            _buildInteractiveResourcesSection(),
            const TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Introduction Section
  // ===========================================================================

  Widget _buildIntroductionSection() {
    return _DemoCard(
      tomId: 'demo21.intro',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'demo21.intro.explanation',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const TomSizedBox(height: 16),
          _InfoBox(tomId: 'demo21.intro.tip'),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 1: Text Resources
  // ===========================================================================

  Widget _buildTextResourcesSection() {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomText with label suffix
        _DemoCard(
          tomId: 'demo21.textDemo',
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display various text styles - all resolved from resources
              TomText(
                tomId: 'demo21.textDemo.display',
                style: theme.textTheme.headlineMedium,
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo21.textDemo.body',
                style: theme.textTheme.bodyLarge,
              ),
              const TomSizedBox(height: 12),
              TomText(
                tomId: 'demo21.textDemo.caption',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // TomBadge with label suffix
        _DemoCard(
          tomId: 'demo21.badgeDemo',
          child: TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomBadge(tomId: 'demo21.badgeDemo.new'),
              TomBadge(
                tomId: 'demo21.badgeDemo.featured',
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
              TomBadge(
                tomId: 'demo21.badgeDemo.sale',
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: Icon Resources
  // ===========================================================================

  Widget _buildIconResourcesSection() {
    return _DemoCard(
      tomId: 'demo21.iconDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icons resolved from resources (icon, alt suffixes)
          TomWrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              // Basic icon resolution
              _IconShowcase(
                tomId: 'demo21.iconDemo.home',
                description: 'Home icon',
              ),
              _IconShowcase(
                tomId: 'demo21.iconDemo.settings',
                description: 'Settings icon',
              ),
              _IconShowcase(
                tomId: 'demo21.iconDemo.user',
                description: 'User icon',
              ),
              _IconShowcase(
                tomId: 'demo21.iconDemo.notification',
                description: 'Notification icon',
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Icon with size parameter resolved from resource
          TomText(
            tomId: 'demo21.iconDemo.sizeLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 8),
          TomRow(
            children: [
              // These icons get their size from resources
              TomIcon(tomId: 'demo21.iconDemo.small'),
              const TomSizedBox(width: 16),
              TomIcon(tomId: 'demo21.iconDemo.medium'),
              const TomSizedBox(width: 16),
              TomIcon(tomId: 'demo21.iconDemo.large'),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Button Resources
  // ===========================================================================

  Widget _buildButtonResourcesSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Elevated buttons - label and icon from resources
        _DemoCard(
          tomId: 'demo21.elevatedDemo',
          child: TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomElevatedButton(
                tomId: 'demo21.elevatedDemo.save',
                onPressed: () {},
              ),
              TomElevatedButton(
                tomId: 'demo21.elevatedDemo.cancel',
                onPressed: () {},
              ),
              TomElevatedButton(
                tomId: 'demo21.elevatedDemo.submit',
                onPressed: () {},
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Filled buttons - with icons
        _DemoCard(
          tomId: 'demo21.filledDemo',
          child: TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomFilledButton(
                tomId: 'demo21.filledDemo.add',
                onPressed: () {},
              ),
              TomFilledButton(
                tomId: 'demo21.filledDemo.edit',
                onPressed: () {},
              ),
              TomFilledButton(
                tomId: 'demo21.filledDemo.delete',
                onPressed: () {},
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // Icon buttons - tooltip from resources
        _DemoCard(
          tomId: 'demo21.iconButtonDemo',
          child: TomWrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              TomIconButton(
                tomId: 'demo21.iconButtonDemo.refresh',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo21.iconButtonDemo.search',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo21.iconButtonDemo.filter',
                onPressed: () {},
              ),
              TomIconButton.filled(
                tomId: 'demo21.iconButtonDemo.add',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 4: Input Resources
  // ===========================================================================

  Widget _buildInputResourcesSection() {
    return _DemoCard(
      tomId: 'demo21.inputDemo',
      child: Form(
        key: _formKey,
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TextFormField with label, hint, helper from resources
            TomTextFormField(
              tomId: 'demo21.inputDemo.username',
            ),
            const TomSizedBox(height: 20),

            // TextFormField with error format from resources
            TomTextFormField(
              tomId: 'demo21.inputDemo.email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  // Error message is resolved from resources
                  return TomUIResources.resolveText(
                    'demo21.inputDemo.email',
                    'errorFormat',
                  );
                }
                if (!value.contains('@')) {
                  return TomUIResources.resolveText(
                    'demo21.inputDemo.email',
                    'errorInvalid',
                  );
                }
                return null;
              },
            ),
            const TomSizedBox(height: 20),

            // TextFormField with password styling
            TomTextFormField(
              tomId: 'demo21.inputDemo.password',
              obscureText: true,
            ),
            const TomSizedBox(height: 16),

            // Validate button
            TomFilledButton(
              tomId: 'demo21.inputDemo.validate',
              onPressed: () {
                _formKey.currentState!.validate();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 5: List & Tile Resources
  // ===========================================================================

  Widget _buildListResourcesSection() {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ListTile with titleText from resources
        _DemoCard(
          tomId: 'demo21.listDemo',
          child: TomColumn(
            children: [
              TomListTile(
                tomId: 'demo21.listDemo.profile',
              ),
              const TomDivider(),
              TomListTile(
                tomId: 'demo21.listDemo.settings',
              ),
              const TomDivider(),
              TomListTile(
                tomId: 'demo21.listDemo.help',
              ),
            ],
          ),
        ),
        const TomSizedBox(height: 16),

        // ExpansionTile with title from resources
        _DemoCard(
          tomId: 'demo21.expansionDemo',
          child: TomColumn(
            children: [
              TomExpansionTile(
                tomId: 'demo21.expansionDemo.general',
                children: [
                  TomListTile(
                    tomId: 'demo21.expansionDemo.general.theme',
                  ),
                  TomListTile(
                    tomId: 'demo21.expansionDemo.general.language',
                  ),
                ],
              ),
              TomExpansionTile(
                tomId: 'demo21.expansionDemo.privacy',
                children: [
                  TomListTile(
                    tomId: 'demo21.expansionDemo.privacy.data',
                  ),
                  TomListTile(
                    tomId: 'demo21.expansionDemo.privacy.cookies',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 6: Interactive Resources
  // ===========================================================================

  Widget _buildInteractiveResourcesSection() {
    return _DemoCard(
      tomId: 'demo21.interactiveDemo',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tooltip with message from resources
          TomText(
            tomId: 'demo21.interactiveDemo.tooltipLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 12),
          TomWrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              TomTooltip(
                tomId: 'demo21.interactiveDemo.tooltip1',
                child: TomContainer(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(
                    tomId: 'demo21.interactiveDemo.tooltip1.content',
                  ),
                ),
              ),
              TomTooltip(
                tomId: 'demo21.interactiveDemo.tooltip2',
                child: TomContainer(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TomText(
                    tomId: 'demo21.interactiveDemo.tooltip2.content',
                  ),
                ),
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Info boxes with messages from resources
          TomText(
            tomId: 'demo21.interactiveDemo.bannerLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const TomSizedBox(height: 12),
          _InfoBox(
            tomId: 'demo21.interactiveDemo.success',
            color: Theme.of(context).colorScheme.primaryContainer,
            icon: Icons.check_circle,
          ),
          const TomSizedBox(height: 8),
          _InfoBox(
            tomId: 'demo21.interactiveDemo.warning',
            color: Theme.of(context).colorScheme.tertiaryContainer,
            icon: Icons.warning_amber,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header with title and subtitle from resources.
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({required this.tomId});

  @override
  Widget build(BuildContext context) {
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
        const TomSizedBox(height: 4),
        TomText(
          tomId: '$tomId.subtitle',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const TomSizedBox(height: 8),
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

/// Demo card with title, description, and icon from resources.
class _DemoCard extends StatelessWidget {
  final String tomId;
  final Widget child;

  const _DemoCard({
    required this.tomId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header with icon and title from resources
            TomRow(
              children: [
                TomIcon(tomId: '$tomId.icon'),
                const TomSizedBox(width: 12),
                TomExpanded(
                  child: TomColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TomText(
                        tomId: '$tomId.title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TomText(
                        tomId: '$tomId.description',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const TomSizedBox(height: 16),
            const TomDivider(),
            const TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Icon showcase widget showing icon with description.
class _IconShowcase extends StatelessWidget {
  final String tomId;
  final String description;

  const _IconShowcase({
    required this.tomId,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        TomContainer(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TomIcon(tomId: tomId),
        ),
        const TomSizedBox(height: 4),
        TomText(
          text: description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Info box showing a message from resources with colored background.
class _InfoBox extends StatelessWidget {
  final String tomId;
  final Color? color;
  final IconData? icon;

  const _InfoBox({
    required this.tomId,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boxColor = color ?? theme.colorScheme.primaryContainer;
    final iconWidget = icon ?? Icons.info;
    
    return TomContainer(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TomRow(
        children: [
          Icon(iconWidget, size: 20),
          const TomSizedBox(width: 12),
          TomExpanded(
            child: TomText(
              tomId: '$tomId.message',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
