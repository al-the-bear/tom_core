/// Demo 01: Button Showcase
///
/// Comprehensive demonstration of all Tom button widgets.
/// Widgets covered: TomElevatedButton, TomFilledButton, TomTextButton,
/// TomOutlinedButton, TomIconButton, TomFloatingActionButton,
/// TomSegmentedButton, TomMenuItemButton, TomSubmenuButton, TomMenuBar,
/// TomBackButton, TomCloseButton, TomCupertinoButton, and more.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the Buttons demo.
class ButtonsDemo extends TomStatelessWidget {
  ButtonsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _ButtonsDemoContent();
  }
}

class _ButtonsDemoContent extends TomStatefulWidget {
  _ButtonsDemoContent();

  @override
  State<_ButtonsDemoContent> createState() => _ButtonsDemoContentState();
}

class _ButtonsDemoContentState extends TomState<_ButtonsDemoContent> {
  // State for interactive demos
  Set<String> _selectedFormats = {'bold'};
  String _selectedView = 'day';
  bool _isExpanded = false;

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Primary Buttons
            _SectionHeader(tomId: 'section.primary'),
            TomSizedBox(height: 16),
            _buildElevatedButtonSection(),
            TomSizedBox(height: 24),
            _buildFilledButtonSection(),
            TomSizedBox(height: 32),

            // Section 2: Secondary Buttons
            _SectionHeader(tomId: 'section.secondary'),
            TomSizedBox(height: 16),
            _buildTextButtonSection(),
            TomSizedBox(height: 24),
            _buildOutlinedButtonSection(),
            TomSizedBox(height: 32),

            // Section 3: Icon & FAB Buttons
            _SectionHeader(tomId: 'section.iconFab'),
            TomSizedBox(height: 16),
            _buildIconButtonSection(),
            TomSizedBox(height: 24),
            _buildFabSection(),
            TomSizedBox(height: 32),

            // Section 4: Segmented & Menu Buttons
            _SectionHeader(tomId: 'section.segmentedMenu'),
            TomSizedBox(height: 16),
            _buildSegmentedButtonSection(),
            TomSizedBox(height: 24),
            _buildMenuButtonSection(),
            TomSizedBox(height: 32),

            // Section 5: Navigation Buttons
            _SectionHeader(tomId: 'section.navigation'),
            TomSizedBox(height: 16),
            _buildNavigationButtonSection(),
            TomSizedBox(height: 32),

            // Section 6: ACL Layout Demo (RTL/LTR)
            _SectionHeader(tomId: 'section.acl'),
            TomSizedBox(height: 16),
            _buildAclButtonSection(),
            TomSizedBox(height: 24),
            _buildAclIconRowSection(),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Primary Buttons
  // ===========================================================================

  Widget _buildElevatedButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'elevated',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic variants row
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomElevatedButton(tomId: 'elevated.basic', onPressed: () {}),
                TomElevatedButton(tomId: 'elevated.disabled', onPressed: null),
              ],
            ),
            TomSizedBox(height: 16),

            // With icons row
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomElevatedButton(tomId: 'elevated.save', onPressed: () {}),
                TomElevatedButton(tomId: 'elevated.send', onPressed: () {}),
                TomElevatedButton(tomId: 'elevated.download', onPressed: () {}),
              ],
            ),
            TomSizedBox(height: 16),

            // Styled variants
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomElevatedButton(
                  tomId: 'elevated.error',
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
                TomElevatedButton(
                  tomId: 'elevated.rounded',
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                ),
                TomElevatedButton(
                  tomId: 'elevated.large',
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'filled',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic filled buttons
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomFilledButton(tomId: 'filled.basic', onPressed: () {}),
                TomFilledButton(tomId: 'filled.disabled', onPressed: null),
              ],
            ),
            TomSizedBox(height: 16),

            // Tonal variants
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomFilledButton(
                  tonal: true,
                  tomId: 'filled.tonal',
                  onPressed: () {},
                ),
                TomFilledButton(
                  tonal: true,
                  tomId: 'filled.tonalSettings',
                  onPressed: () {},
                ),
                TomFilledButton(
                  tonal: true,
                  tomId: 'filled.tonalDisabled',
                  onPressed: null,
                ),
              ],
            ),
            TomSizedBox(height: 16),

            // With icons
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomFilledButton(tomId: 'filled.add', onPressed: () {}),
                TomFilledButton(tomId: 'filled.share', onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 2: Secondary Buttons
  // ===========================================================================

  Widget _buildTextButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'text',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic variants
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomTextButton(tomId: 'text.basic', onPressed: () {}),
                TomTextButton(tomId: 'text.disabled', onPressed: null),
              ],
            ),
            TomSizedBox(height: 16),

            // With icons
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomTextButton(tomId: 'text.link', onPressed: () {}),
                TomTextButton(tomId: 'text.more', onPressed: () {}),
              ],
            ),
            TomSizedBox(height: 16),

            // Dialog-style buttons
            TomCard(
              child: TomPadding(
                padding: const EdgeInsets.all(16),
                child: TomRow(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TomTextButton(tomId: 'text.cancel', onPressed: () {}),
                    TomSizedBox(width: 8),
                    TomTextButton(tomId: 'text.ok', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'outlined',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic variants
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomOutlinedButton(tomId: 'outlined.basic', onPressed: () {}),
                TomOutlinedButton(tomId: 'outlined.disabled', onPressed: null),
              ],
            ),
            TomSizedBox(height: 16),

            // With icons
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomOutlinedButton(tomId: 'outlined.edit', onPressed: () {}),
                TomOutlinedButton(tomId: 'outlined.cancel', onPressed: () {}),
              ],
            ),
            TomSizedBox(height: 16),

            // Styled variants
            TomWrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TomOutlinedButton(
                  tomId: 'outlined.thick',
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      width: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                TomOutlinedButton(
                  tomId: 'outlined.secondary',
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 3: Icon & FAB Buttons
  // ===========================================================================

  Widget _buildIconButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'icon',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic icon buttons
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomIconButton(tomId: 'icon.favorite', onPressed: () {}),
                TomIconButton(tomId: 'icon.share', onPressed: () {}),
                TomIconButton(tomId: 'icon.more', onPressed: () {}),
                TomIconButton(tomId: 'icon.disabled', onPressed: null),
              ],
            ),
            TomSizedBox(height: 16),

            // Variants (filled, outlined, tonal)
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TomIconButton.filled(tomId: 'icon.filled', onPressed: () {}),
                TomIconButton.filledTonal(
                  tomId: 'icon.tonal',
                  onPressed: () {},
                ),
                TomIconButton.outlined(
                  tomId: 'icon.outlined',
                  onPressed: () {},
                ),
              ],
            ),
            TomSizedBox(height: 16),

            // Size variants
            TomWrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TomIconButton(
                  tomId: 'icon.small',
                  onPressed: () {},
                  iconSize: 18,
                ),
                TomIconButton(
                  tomId: 'icon.medium',
                  onPressed: () {},
                  iconSize: 24,
                ),
                TomIconButton(
                  tomId: 'icon.large',
                  onPressed: () {},
                  iconSize: 32,
                ),
                TomIconButton(
                  tomId: 'icon.xlarge',
                  onPressed: () {},
                  iconSize: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'fab',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standard FABs
            TomWrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TomFloatingActionButton(
                  tomId: 'fab.basic',
                  heroTag: 'fab_basic',
                  onPressed: () {},
                ),
                TomFloatingActionButton.small(
                  tomId: 'fab.small',
                  heroTag: 'fab_small',
                  onPressed: () {},
                ),
                TomFloatingActionButton.large(
                  tomId: 'fab.large',
                  heroTag: 'fab_large',
                  onPressed: () {},
                ),
              ],
            ),
            TomSizedBox(height: 24),

            // Extended FABs
            TomWrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TomFloatingActionButton.extended(
                  tomId: 'fab.compose',
                  heroTag: 'fab_compose',
                  onPressed: () {},
                ),
                TomFloatingActionButton.extended(
                  tomId: 'fab.create',
                  heroTag: 'fab_create',
                  onPressed: () {},
                ),
              ],
            ),
            TomSizedBox(height: 24),

            // Color variants
            TomWrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TomFloatingActionButton(
                  tomId: 'fab.tertiary',
                  heroTag: 'fab_tertiary',
                  onPressed: () {},
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onTertiaryContainer,
                ),
                TomFloatingActionButton(
                  tomId: 'fab.error',
                  heroTag: 'fab_error',
                  onPressed: () {},
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 4: Segmented & Menu Buttons
  // ===========================================================================

  Widget _buildSegmentedButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'segmented',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Single select
            TomSegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'day',
                  icon: TomIcon(tomId: 'segmented.day'),
                  label: TomText(tomId: 'segmented.day'),
                ),
                ButtonSegment<String>(
                  value: 'week',
                  icon: TomIcon(tomId: 'segmented.week'),
                  label: TomText(tomId: 'segmented.week'),
                ),
                ButtonSegment<String>(
                  value: 'month',
                  icon: TomIcon(tomId: 'segmented.month'),
                  label: TomText(tomId: 'segmented.month'),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (selection) {
                setState(() => _selectedView = selection.first);
              },
            ),
            TomSizedBox(height: 24),

            // Multi select (text formatting)
            TomSegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'bold',
                  icon: TomIcon(tomId: 'segmented.bold'),
                  label: TomText(tomId: 'segmented.bold'),
                ),
                ButtonSegment<String>(
                  value: 'italic',
                  icon: TomIcon(tomId: 'segmented.italic'),
                  label: TomText(tomId: 'segmented.italic'),
                ),
                ButtonSegment<String>(
                  value: 'underline',
                  icon: TomIcon(tomId: 'segmented.underline'),
                  label: TomText(tomId: 'segmented.underline'),
                ),
              ],
              selected: _selectedFormats,
              multiSelectionEnabled: true,
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) {
                setState(() => _selectedFormats = selection);
              },
            ),
            TomSizedBox(height: 24),

            // Icon only (compact)
            TomSegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'list',
                  icon: TomIcon(tomId: 'segmented.list'),
                ),
                ButtonSegment<String>(
                  value: 'grid',
                  icon: TomIcon(tomId: 'segmented.grid'),
                ),
                ButtonSegment<String>(
                  value: 'module',
                  icon: TomIcon(tomId: 'segmented.module'),
                ),
              ],
              selected: const {'list'},
              showSelectedIcon: false,
              onSelectionChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'menu',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Menu
            TomMenuAnchor(
              menuChildren: [
                TomMenuItemButton(tomId: 'menu.cut', onPressed: () {}),
                TomMenuItemButton(tomId: 'menu.copy', onPressed: () {}),
                TomMenuItemButton(tomId: 'menu.paste', onPressed: () {}),
                TomDivider(),
                TomMenuItemButton(tomId: 'menu.selectAll', onPressed: () {}),
              ],
              builder: (context, controller, child) {
                return TomFilledButton(
                  tonal: true,
                  tomId: 'menu.trigger',
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
            ),
            TomSizedBox(height: 24),

            // Submenu demo
            TomMenuAnchor(
              menuChildren: [
                TomSubmenuButton(
                  menuChildren: [
                    TomMenuItemButton(tomId: 'submenu.new', onPressed: () {}),
                    TomSubmenuButton(
                      menuChildren: [
                        TomMenuItemButton(
                          tomId: 'submenu.openRecent',
                          onPressed: () {},
                        ),
                        TomMenuItemButton(
                          tomId: 'submenu.openBrowse',
                          onPressed: () {},
                        ),
                      ],
                      child: TomText(tomId: 'submenu.open'),
                    ),
                  ],
                  child: TomText(tomId: 'submenu.file'),
                ),
                TomSubmenuButton(
                  menuChildren: [
                    TomMenuItemButton(
                      tomId: 'submenu.exportPdf',
                      onPressed: () {},
                    ),
                    TomMenuItemButton(
                      tomId: 'submenu.exportCsv',
                      onPressed: () {},
                    ),
                    TomMenuItemButton(
                      tomId: 'submenu.exportJson',
                      onPressed: () {},
                    ),
                  ],
                  child: TomText(tomId: 'submenu.export'),
                ),
              ],
              builder: (context, controller, child) {
                return TomOutlinedButton(
                  tomId: 'submenu.trigger',
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
            ),
            TomSizedBox(height: 24),

            // PopupMenuButton style
            TomPopupMenuButton<String>(
              tomId: 'popup',
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'view',
                  child: TomText(tomId: 'popup.view'),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: TomText(tomId: 'popup.edit'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: TomText(tomId: 'popup.delete'),
                ),
              ],
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 5: Navigation Buttons
  // ===========================================================================

  Widget _buildNavigationButtonSection() {
    final direction = AclDirectionScope.maybeOf(context);
    final textDirection = direction == AclDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'navigation',
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back and Close buttons
            TomWrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TomBackButton(tomId: 'navigation.back', onPressed: () {}),
                TomCloseButton(tomId: 'navigation.close', onPressed: () {}),
              ],
            ),
            TomSizedBox(height: 24),

            // Expand icon (animated)
            TomRow(
              children: [
                TomExpandIcon(
                  isExpanded: _isExpanded,
                  onPressed: (_) {
                    setState(() => _isExpanded = !_isExpanded);
                  },
                ),
                TomSizedBox(width: 8),
                TomText(
                  tomId: _isExpanded
                      ? 'demo01.expand.collapse'
                      : 'demo01.expand.expand',
                ),
              ],
            ),
            TomSizedBox(height: 24),

            // Context bar example
            TomCard(
              child: TomPadding(
                padding: const EdgeInsets.all(8),
                child: TomRow(
                  children: [
                    TomBackButton(tomId: 'context.back', onPressed: () {}),
                    TomExpanded(
                      child: TomCenter(child: TomText(tomId: 'context.title')),
                    ),
                    TomIconButton(tomId: 'context.more', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 6: ACL Layout Demo (RTL/LTR)
  // ===========================================================================

  Widget _buildAclButtonSection() {
    return _DemoCard(
      tomId: 'aclButtons',
      child: AclBuilder()
          // Row 1: Label + Button side by side
          .append(TomText(tomId: 'aclButtons.primaryLabel'))
          .append(
            TomElevatedButton(tomId: 'aclButtons.primary', onPressed: () {}),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 2: Label + Button side by side
          .append(TomText(tomId: 'aclButtons.secondaryLabel'))
          .append(
            TomOutlinedButton(tomId: 'aclButtons.secondary', onPressed: () {}),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 3: Multiple buttons aligned
          .append(TomTextButton(tomId: 'aclButtons.cancel', onPressed: () {}))
          .gap()
          .append(
            TomFilledButton(tomId: 'aclButtons.save', onPressed: () {}),
            dist: 8,
          )
          .build(),
    );
  }

  Widget _buildAclIconRowSection() {
    return _DemoCard(
      tomId: 'aclIconRow',
      child: AclBuilder()
          // Row 1: Icon buttons in a row
          .append(TomIconButton(tomId: 'aclIconRow.back', onPressed: () {}))
          .append(TomText(tomId: 'aclIconRow.pageTitle'), dist: 8)
          .expandX()
          .append(TomIconButton(tomId: 'aclIconRow.settings', onPressed: () {}))
          .append(
            TomIconButton(tomId: 'aclIconRow.menu', onPressed: () {}),
            dist: 4,
          )
          .newRow(dist: 24)
          // Row 2: FAB row
          .append(TomText(tomId: 'aclIconRow.fabLabel'))
          .gap()
          .append(
            TomFloatingActionButton.small(
              tomId: 'aclIconRow.fab',
              heroTag: 'acl_fab',
              onPressed: () {},
            ),
            dist: 16,
          )
          .build(),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

/// Section header widget for demo sections.
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

/// Demo card widget for individual widget showcases.
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
