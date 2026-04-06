/// Demo 11: Text & Label Display
///
/// Comprehensive demonstration of all Tom text and label widgets.
/// Widgets covered: TomText, TomSelectableText, TomRichText, TomBadge,
/// TomListTile, TomChip, TomFilterChip, TomChoiceChip, TomActionChip,
/// TomInputChip, and TomDefaultTextStyle.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Labels demo.
class LabelsDemo extends TomStatelessWidget {
  LabelsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _LabelsDemoContent();

  }
}

class _LabelsDemoContent extends TomStatefulWidget {
  _LabelsDemoContent();

  @override
  State<_LabelsDemoContent> createState() => _LabelsDemoContentState();
}

class _LabelsDemoContentState extends TomState<_LabelsDemoContent> {
  // State for interactive demos
  final Set<String> _selectedFilterChips = {'dart', 'flutter'};
  String _selectedChoiceChip = 'medium';
  final Set<String> _selectedInputChips = {'tag1'};

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Text Styles
            _SectionHeader(
              tomId: 'section.text',
            ),
            TomSizedBox(height: 16),
            _buildTextSection(),
            TomSizedBox(height: 32),

            // Section 2: Rich & Selectable Text
            _SectionHeader(
              tomId: 'section.rich',
            ),
            TomSizedBox(height: 16),
            _buildRichTextSection(),
            TomSizedBox(height: 24),
            _buildSelectableTextSection(),
            TomSizedBox(height: 32),

            // Section 3: Badges
            _SectionHeader(
              tomId: 'section.badge',
            ),
            TomSizedBox(height: 16),
            _buildBadgeSection(),
            TomSizedBox(height: 32),

            // Section 4: List Tiles
            _SectionHeader(
              tomId: 'section.listTile',
            ),
            TomSizedBox(height: 16),
            _buildListTileSection(),
            TomSizedBox(height: 32),

            // Section 5: Chips (with ACL demo)
            _SectionHeader(
              tomId: 'section.chips',
            ),
            TomSizedBox(height: 16),
            _buildChipSection(),
            TomSizedBox(height: 24),
            _buildFilterChipSection(),
            TomSizedBox(height: 24),
            _buildChoiceChipSection(),
            TomSizedBox(height: 24),
            _buildActionChipSection(),
            TomSizedBox(height: 24),
            _buildInputChipSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Text Styles
  // ===========================================================================

  Widget _buildTextSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'text',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display styles
          TomText(
            tomId: 'text.display',
            style: theme.textTheme.displaySmall,
          ),
          TomSizedBox(height: 16),

          // Headline styles
          TomText(
            tomId: 'text.headline',
            style: theme.textTheme.headlineMedium,
          ),
          TomSizedBox(height: 12),

          // Title styles
          TomText(
            tomId: 'text.titleStyle',
            style: theme.textTheme.titleLarge,
          ),
          TomSizedBox(height: 12),

          // Body styles
          TomText(
            tomId: 'text.body',
            style: theme.textTheme.bodyLarge,
          ),
          TomSizedBox(height: 8),
          TomText(
            tomId: 'text.bodySmall',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 16),

          // Label styles
          TomText(
            tomId: 'text.labelLarge',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TomSizedBox(height: 4),
          TomText(
            tomId: 'text.labelSmall',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
            ),
          ),
          TomSizedBox(height: 16),

          // Styled text variants
          TomWrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TomText(
                tomId: 'text.primary',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TomText(
                tomId: 'text.error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              TomText(
                tomId: 'text.italic',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              TomText(
                tomId: 'text.underline',
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // Overflow handling
          TomText(
            tomId: 'text.overflow',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Rich & Selectable Text
  // ===========================================================================

  Widget _buildRichTextSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'richText',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic rich text with mixed styles
          TomRichText(
            text: TextSpan(
              style: theme.textTheme.bodyLarge,
              children: [
                const TextSpan(text: 'TomRichText supports '),
                TextSpan(
                  text: 'bold',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: 'italic',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: 'colored',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const TextSpan(text: ', and '),
                TextSpan(
                  text: 'underlined',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.secondary,
                  ),
                ),
                const TextSpan(text: ' text.'),
              ],
            ),
          ),
          TomSizedBox(height: 16),

          // Rich text with links simulation
          TomRichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Learn more about '),
                TextSpan(
                  text: 'Flutter',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Dart',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const TextSpan(text: ' programming.'),
              ],
            ),
          ),
          TomSizedBox(height: 16),

          // Rich text with multiple font sizes
          TomRichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'H',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'ello ',
                  style: theme.textTheme.titleLarge,
                ),
                TextSpan(
                  text: 'W',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'orld!',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableTextSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'selectableText',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic selectable text
          TomSelectableText(
            tomId: 'selectableText.basic',
            style: theme.textTheme.bodyLarge,
          ),
          TomSizedBox(height: 16),

          // Selectable text with custom cursor
          TomSelectableText(
            tomId: 'selectableText.cursor',
            style: theme.textTheme.bodyMedium,
            cursorColor: theme.colorScheme.secondary,
            cursorWidth: 3,
            showCursor: true,
          ),
          TomSizedBox(height: 16),

          // Multi-line selectable
          TomSelectableText(
            tomId: 'selectableText.multiline',
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Badges
  // ===========================================================================

  Widget _buildBadgeSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'badge',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges on icons
          TomWrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              TomBadge(
                tomId: 'badge.notifications',
                labelText: '5',
                child: TomIcon(icon: Icons.notifications_outlined),
              ),
              TomBadge(
                tomId: 'badge.messages',
                labelText: '12',
                backgroundColor: theme.colorScheme.error,
                child: TomIcon(icon: Icons.mail_outlined),
              ),
              TomBadge(
                tomId: 'badge.cart',
                labelText: '3',
                backgroundColor: theme.colorScheme.tertiary,
                child: TomIcon(icon: Icons.shopping_cart_outlined),
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Large count badge
          TomWrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              TomBadge(
                tomId: 'badge.large',
                labelText: '99+',
                child: TomIcon(icon: Icons.inbox_outlined),
              ),
              // Small dot badge (no label)
              TomBadge(
                labelText: '',
                isLabelVisible: false,
                child: TomIconButton(
                  tomId: 'badge.dot.button',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          TomSizedBox(height: 24),

          // Badges with custom styling
          TomWrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              TomBadge(
                labelText: 'New',
                backgroundColor: theme.colorScheme.primaryContainer,
                textColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: TomText(
                  tomId: 'badge.custom.feature',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TomBadge(
                labelText: 'Beta',
                backgroundColor: theme.colorScheme.secondaryContainer,
                textColor: theme.colorScheme.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: TomText(
                  tomId: 'badge.custom.product',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: List Tiles
  // ===========================================================================

  Widget _buildListTileSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'listTile',
      child: TomColumn(
        children: [
          // Basic list tile
          TomListTile(
            tomId: 'listTile.basic',
            titleText: 'Basic List Tile',
            subtitle: TomText(text: 'A simple list tile with title and subtitle'),
            leading: TomIcon(icon: Icons.info_outline),
          ),
          TomDivider(height: 1),

          // List tile with trailing
          TomListTile(
            tomId: 'listTile.trailing',
            titleText: 'Settings',
            subtitle: TomText(text: 'Configure your preferences'),
            leading: TomIcon(icon: Icons.settings_outlined),
            trailing: TomIcon(icon: Icons.chevron_right),
            onTap: () {},
          ),
          TomDivider(height: 1),

          // Three-line list tile
          TomListTile(
            tomId: 'listTile.threeLine',
            titleText: 'John Doe',
            subtitle: TomText(
              text: 'Software Engineer\nAvailable for freelance work',
              maxLines: 2,
              style: theme.textTheme.bodySmall,
            ),
            leading: const CircleAvatar(
              child: Text('JD'),
            ),
            isThreeLine: true,
            trailing: TomIconButton(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),
          TomDivider(height: 1),

          // Dense list tile
          TomListTile(
            tomId: 'listTile.dense',
            titleText: 'Dense List Tile',
            subtitle: TomText(text: 'Compact layout'),
            leading: TomIcon(icon: Icons.compress),
            dense: true,
          ),
          TomDivider(height: 1),

          // Selected list tile
          TomListTile(
            tomId: 'listTile.selected',
            titleText: 'Selected Item',
            subtitle: TomText(text: 'This tile is selected'),
            leading: TomIcon(icon: Icons.check_circle),
            selected: true,
            selectedColor: theme.colorScheme.primary,
            selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: Chips
  // ===========================================================================

  Widget _buildChipSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'chip',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic chips
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomChip(
                tomId: 'chip.basic',
                labelText: 'Basic Chip',
              ),
              TomChip(
                tomId: 'chip.avatar',
                labelText: 'With Avatar',
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Text('A', style: TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ),
              TomChip(
                tomId: 'chip.delete',
                labelText: 'Deletable',
                onDeleted: () {},
              ),
            ],
          ),
          TomSizedBox(height: 16),

          // Styled chips
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomChip(
                labelText: 'Primary',
                backgroundColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
              TomChip(
                labelText: 'Secondary',
                backgroundColor: theme.colorScheme.secondaryContainer,
                labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
              TomChip(
                labelText: 'Outlined',
                backgroundColor: Colors.transparent,
                side: BorderSide(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'filterChip',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'filterChip.instruction',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomFilterChip(
                tomId: 'filterChip.dart',
                labelText: 'Dart',
                selected: _selectedFilterChips.contains('dart'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilterChips.add('dart');
                    } else {
                      _selectedFilterChips.remove('dart');
                    }
                  });
                },
              ),
              TomFilterChip(
                tomId: 'filterChip.flutter',
                labelText: 'Flutter',
                selected: _selectedFilterChips.contains('flutter'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilterChips.add('flutter');
                    } else {
                      _selectedFilterChips.remove('flutter');
                    }
                  });
                },
              ),
              TomFilterChip(
                tomId: 'filterChip.web',
                labelText: 'Web',
                selected: _selectedFilterChips.contains('web'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilterChips.add('web');
                    } else {
                      _selectedFilterChips.remove('web');
                    }
                  });
                },
              ),
              TomFilterChip(
                tomId: 'filterChip.mobile',
                labelText: 'Mobile',
                selected: _selectedFilterChips.contains('mobile'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFilterChips.add('mobile');
                    } else {
                      _selectedFilterChips.remove('mobile');
                    }
                  });
                },
              ),
            ],
          ),
          TomSizedBox(height: 12),
          TomText(
            text: 'Selected: ${_selectedFilterChips.join(", ")}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChipSection() {
    final theme = Theme.of(context);
    return _DemoCard(
      tomId: 'choiceChip',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomText(
            tomId: 'choiceChip.instruction',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TomSizedBox(height: 12),
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomChoiceChip(
                tomId: 'choiceChip.small',
                labelText: 'Small',
                selected: _selectedChoiceChip == 'small',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedChoiceChip = 'small');
                  }
                },
              ),
              TomChoiceChip(
                tomId: 'choiceChip.medium',
                labelText: 'Medium',
                selected: _selectedChoiceChip == 'medium',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedChoiceChip = 'medium');
                  }
                },
              ),
              TomChoiceChip(
                tomId: 'choiceChip.large',
                labelText: 'Large',
                selected: _selectedChoiceChip == 'large',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedChoiceChip = 'large');
                  }
                },
              ),
            ],
          ),
          TomSizedBox(height: 12),
          TomText(
            text: 'Selected size: $_selectedChoiceChip',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionChipSection() {
    return _DemoCard(
      tomId: 'actionChip',
      child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomActionChip(
                tomId: 'actionChip.share',
                labelText: 'Share',
                avatar: TomIcon(icon: Icons.share, size: 18),
                onPressed: () {},
              ),
              TomActionChip(
                tomId: 'actionChip.save',
                labelText: 'Save',
                avatar: TomIcon(icon: Icons.bookmark_border, size: 18),
                onPressed: () {},
              ),
              TomActionChip(
                tomId: 'actionChip.copy',
                labelText: 'Copy Link',
                avatar: TomIcon(icon: Icons.link, size: 18),
                onPressed: () {},
              ),
              TomActionChip(
                tomId: 'actionChip.download',
                labelText: 'Download',
                avatar: TomIcon(icon: Icons.download, size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputChipSection() {
    final theme = Theme.of(context);
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'inputChip',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomText(
              tomId: 'inputChip.instruction',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 12),
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomInputChip(
                  tomId: 'inputChip.tag1',
                  labelText: 'Tag 1',
                  selected: _selectedInputChips.contains('tag1'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInputChips.add('tag1');
                      } else {
                        _selectedInputChips.remove('tag1');
                      }
                    });
                  },
                  onDeleted: () {
                    setState(() => _selectedInputChips.remove('tag1'));
                  },
                ),
                TomInputChip(
                  tomId: 'inputChip.tag2',
                  labelText: 'Tag 2',
                  selected: _selectedInputChips.contains('tag2'),
                  avatar: CircleAvatar(
                    radius: 12,
                    child: TomIcon(icon: Icons.tag, size: 12),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInputChips.add('tag2');
                      } else {
                        _selectedInputChips.remove('tag2');
                      }
                    });
                  },
                  onDeleted: () {
                    setState(() => _selectedInputChips.remove('tag2'));
                  },
                ),
                TomInputChip(
                  tomId: 'inputChip.tag3',
                  labelText: 'Tag 3',
                  selected: _selectedInputChips.contains('tag3'),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInputChips.add('tag3');
                      } else {
                        _selectedInputChips.remove('tag3');
                      }
                    });
                  },
                  onDeleted: () {
                    setState(() => _selectedInputChips.remove('tag3'));
                  },
                ),
              ],
            ),
            TomSizedBox(height: 16),
            // RTL/LTR info
            TomRow(
              children: [
                TomIcon(
                  icon: direction == AclDirection.rtl
                      ? Icons.format_textdirection_r_to_l
                      : Icons.format_textdirection_l_to_r,
                  size: 16,
                ),
                TomSizedBox(width: 8),
                TomText(
                  text: direction == AclDirection.rtl
                      ? 'Right-to-Left layout'
                      : 'Left-to-Right layout',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header with title, subtitle, and gradient divider.
class _SectionHeader extends TomStatelessWidget {
  final String tomId;

  _SectionHeader({
    required this.tomId,
  });

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

/// Demo card widget for individual widget showcases.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({
    required this.tomId,
    required this.child,
  });

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
            // Title row with icon
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
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TomSizedBox(height: 16),
            TomDivider(),
            TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
