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
class ButtonsDemo extends StatelessWidget {
  const ButtonsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ButtonsDemoContent();
  }
}

class _ButtonsDemoContent extends StatefulWidget {
  const _ButtonsDemoContent();

  @override
  State<_ButtonsDemoContent> createState() => _ButtonsDemoContentState();
}

class _ButtonsDemoContentState extends State<_ButtonsDemoContent> {
  // State for interactive demos
  Set<String> _selectedFormats = {'bold'};
  String _selectedView = 'day';
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Primary Buttons
            _SectionHeader(
              tomId: 'demo01.section.primary',
            ),
            const TomSizedBox(height: 16),
            _buildElevatedButtonSection(),
            const TomSizedBox(height: 24),
            _buildFilledButtonSection(),
            const TomSizedBox(height: 32),

            // Section 2: Secondary Buttons
            _SectionHeader(
              tomId: 'demo01.section.secondary',
            ),
            const TomSizedBox(height: 16),
            _buildTextButtonSection(),
            const TomSizedBox(height: 24),
            _buildOutlinedButtonSection(),
            const TomSizedBox(height: 32),

            // Section 3: Icon & FAB Buttons
            _SectionHeader(
              tomId: 'demo01.section.iconFab',
            ),
            const TomSizedBox(height: 16),
            _buildIconButtonSection(),
            const TomSizedBox(height: 24),
            _buildFabSection(),
            const TomSizedBox(height: 32),

            // Section 4: Segmented & Menu Buttons
            _SectionHeader(
              tomId: 'demo01.section.segmentedMenu',
            ),
            const TomSizedBox(height: 16),
            _buildSegmentedButtonSection(),
            const TomSizedBox(height: 24),
            _buildMenuButtonSection(),
            const TomSizedBox(height: 32),

            // Section 5: Navigation Buttons
            _SectionHeader(
              tomId: 'demo01.section.navigation',
            ),
            const TomSizedBox(height: 16),
            _buildNavigationButtonSection(),
            const TomSizedBox(height: 32),

            // Section 6: ACL Layout Demo (RTL/LTR)
            _SectionHeader(
              tomId: 'demo01.section.acl',
            ),
            const TomSizedBox(height: 16),
            _buildAclButtonSection(),
            const TomSizedBox(height: 24),
            _buildAclIconRowSection(),
            const TomSizedBox(height: 48),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.elevated',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic variants row
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomElevatedButton(
                tomId: 'demo01.elevated.basic',
                onPressed: () {},
              ),
              TomElevatedButton(
                tomId: 'demo01.elevated.disabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // With icons row
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomElevatedButton(
                tomId: 'demo01.elevated.save',
                onPressed: () {},
              ),
              TomElevatedButton(
                tomId: 'demo01.elevated.send',
                onPressed: () {},
              ),
              TomElevatedButton(
                tomId: 'demo01.elevated.download',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Styled variants
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomElevatedButton(
                tomId: 'demo01.elevated.error',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              ),
              TomElevatedButton(
                tomId: 'demo01.elevated.rounded',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                ),
              ),
              TomElevatedButton(
                tomId: 'demo01.elevated.large',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.filled',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic filled buttons
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomFilledButton(
                tomId: 'demo01.filled.basic',
                onPressed: () {},
              ),
              TomFilledButton(
                tomId: 'demo01.filled.disabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Tonal variants
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomFilledButton(
                tonal: true,
                tomId: 'demo01.filled.tonal',
                onPressed: () {},
              ),
              TomFilledButton(
                tonal: true,
                tomId: 'demo01.filled.tonalSettings',
                onPressed: () {},
              ),
              TomFilledButton(
                tonal: true,
                tomId: 'demo01.filled.tonalDisabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // With icons
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomFilledButton(
                tomId: 'demo01.filled.add',
                onPressed: () {},
              ),
              TomFilledButton(
                tomId: 'demo01.filled.share',
                onPressed: () {},
              ),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.text',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic variants
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomTextButton(
                tomId: 'demo01.text.basic',
                onPressed: () {},
              ),
              TomTextButton(
                tomId: 'demo01.text.disabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // With icons
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomTextButton(
                tomId: 'demo01.text.link',
                onPressed: () {},
              ),
              TomTextButton(
                tomId: 'demo01.text.more',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Dialog-style buttons
          TomCard(
            child: TomPadding(
              padding: const EdgeInsets.all(16),
              child: TomRow(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TomTextButton(
                    tomId: 'demo01.text.cancel',
                    onPressed: () {},
                  ),
                  const TomSizedBox(width: 8),
                  TomTextButton(
                    tomId: 'demo01.text.ok',
                    onPressed: () {},
                  ),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.outlined',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic variants
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomOutlinedButton(
                tomId: 'demo01.outlined.basic',
                onPressed: () {},
              ),
              TomOutlinedButton(
                tomId: 'demo01.outlined.disabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // With icons
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomOutlinedButton(
                tomId: 'demo01.outlined.edit',
                onPressed: () {},
              ),
              TomOutlinedButton(
                tomId: 'demo01.outlined.cancel',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Styled variants
          TomWrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              TomOutlinedButton(
                tomId: 'demo01.outlined.thick',
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              TomOutlinedButton(
                tomId: 'demo01.outlined.secondary',
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.icon',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic icon buttons
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomIconButton(
                tomId: 'demo01.icon.favorite',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo01.icon.share',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo01.icon.more',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo01.icon.disabled',
                onPressed: null,
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Variants (filled, outlined, tonal)
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomIconButton.filled(
                tomId: 'demo01.icon.filled',
                onPressed: () {},
              ),
              TomIconButton.filledTonal(
                tomId: 'demo01.icon.tonal',
                onPressed: () {},
              ),
              TomIconButton.outlined(
                tomId: 'demo01.icon.outlined',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 16),

          // Size variants
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TomIconButton(
                tomId: 'demo01.icon.small',
                onPressed: () {},
                iconSize: 18,
              ),
              TomIconButton(
                tomId: 'demo01.icon.medium',
                onPressed: () {},
                iconSize: 24,
              ),
              TomIconButton(
                tomId: 'demo01.icon.large',
                onPressed: () {},
                iconSize: 32,
              ),
              TomIconButton(
                tomId: 'demo01.icon.xlarge',
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.fab',
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
                tomId: 'demo01.fab.basic',
                heroTag: 'fab_basic',
                onPressed: () {},
              ),
              TomFloatingActionButton.small(
                tomId: 'demo01.fab.small',
                heroTag: 'fab_small',
                onPressed: () {},
              ),
              TomFloatingActionButton.large(
                tomId: 'demo01.fab.large',
                heroTag: 'fab_large',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Extended FABs
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomFloatingActionButton.extended(
                tomId: 'demo01.fab.compose',
                heroTag: 'fab_compose',
                onPressed: () {},
              ),
              TomFloatingActionButton.extended(
                tomId: 'demo01.fab.create',
                heroTag: 'fab_create',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Color variants
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomFloatingActionButton(
                tomId: 'demo01.fab.tertiary',
                heroTag: 'fab_tertiary',
                onPressed: () {},
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              TomFloatingActionButton(
                tomId: 'demo01.fab.error',
                heroTag: 'fab_error',
                onPressed: () {},
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.segmented',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single select
          TomSegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'day',
                icon: TomIcon(tomId: 'demo01.segmented.day'),
                label: TomText(tomId: 'demo01.segmented.day'),
              ),
              ButtonSegment<String>(
                value: 'week',
                icon: TomIcon(tomId: 'demo01.segmented.week'),
                label: TomText(tomId: 'demo01.segmented.week'),
              ),
              ButtonSegment<String>(
                value: 'month',
                icon: TomIcon(tomId: 'demo01.segmented.month'),
                label: TomText(tomId: 'demo01.segmented.month'),
              ),
            ],
            selected: {_selectedView},
            onSelectionChanged: (selection) {
              setState(() => _selectedView = selection.first);
            },
          ),
          const TomSizedBox(height: 24),

          // Multi select (text formatting)
          TomSegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'bold',
                icon: TomIcon(tomId: 'demo01.segmented.bold'),
                label: TomText(tomId: 'demo01.segmented.bold'),
              ),
              ButtonSegment<String>(
                value: 'italic',
                icon: TomIcon(tomId: 'demo01.segmented.italic'),
                label: TomText(tomId: 'demo01.segmented.italic'),
              ),
              ButtonSegment<String>(
                value: 'underline',
                icon: TomIcon(tomId: 'demo01.segmented.underline'),
                label: TomText(tomId: 'demo01.segmented.underline'),
              ),
            ],
            selected: _selectedFormats,
            multiSelectionEnabled: true,
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              setState(() => _selectedFormats = selection);
            },
          ),
          const TomSizedBox(height: 24),

          // Icon only (compact)
          TomSegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'list',
                icon: TomIcon(tomId: 'demo01.segmented.list'),
              ),
              ButtonSegment<String>(
                value: 'grid',
                icon: TomIcon(tomId: 'demo01.segmented.grid'),
              ),
              ButtonSegment<String>(
                value: 'module',
                icon: TomIcon(tomId: 'demo01.segmented.module'),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.menu',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Menu
          TomMenuAnchor(
            menuChildren: [
              TomMenuItemButton(
                tomId: 'demo01.menu.cut',
                onPressed: () {},
              ),
              TomMenuItemButton(
                tomId: 'demo01.menu.copy',
                onPressed: () {},
              ),
              TomMenuItemButton(
                tomId: 'demo01.menu.paste',
                onPressed: () {},
              ),
              const TomDivider(),
              TomMenuItemButton(
                tomId: 'demo01.menu.selectAll',
                onPressed: () {},
              ),
            ],
            builder: (context, controller, child) {
              return TomFilledButton(
                tonal: true,
                tomId: 'demo01.menu.trigger',
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
          const TomSizedBox(height: 24),

          // Submenu demo
          TomMenuAnchor(
            menuChildren: [
              TomSubmenuButton(
                menuChildren: [
                  TomMenuItemButton(
                    tomId: 'demo01.submenu.new',
                    onPressed: () {},
                  ),
                  TomSubmenuButton(
                    menuChildren: [
                      TomMenuItemButton(
                        tomId: 'demo01.submenu.openRecent',
                        onPressed: () {},
                      ),
                      TomMenuItemButton(
                        tomId: 'demo01.submenu.openBrowse',
                        onPressed: () {},
                      ),
                    ],
                    child: TomText(tomId: 'demo01.submenu.open'),
                  ),
                ],
                child: TomText(tomId: 'demo01.submenu.file'),
              ),
              TomSubmenuButton(
                menuChildren: [
                  TomMenuItemButton(
                    tomId: 'demo01.submenu.exportPdf',
                    onPressed: () {},
                  ),
                  TomMenuItemButton(
                    tomId: 'demo01.submenu.exportCsv',
                    onPressed: () {},
                  ),
                  TomMenuItemButton(
                    tomId: 'demo01.submenu.exportJson',
                    onPressed: () {},
                  ),
                ],
                child: TomText(tomId: 'demo01.submenu.export'),
              ),
            ],
            builder: (context, controller, child) {
              return TomOutlinedButton(
                tomId: 'demo01.submenu.trigger',
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
          const TomSizedBox(height: 24),

          // PopupMenuButton style
          TomPopupMenuButton<String>(
            tomId: 'demo01.popup',
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'view',
                child: TomText(tomId: 'demo01.popup.view'),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                child: TomText(tomId: 'demo01.popup.edit'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: TomText(tomId: 'demo01.popup.delete'),
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
    final textDirection =
        direction == AclDirection.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: _DemoCard(
        tomId: 'demo01.navigation',
        child: TomColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back and Close buttons
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomBackButton(
                tomId: 'demo01.navigation.back',
                onPressed: () {},
              ),
              TomCloseButton(
                tomId: 'demo01.navigation.close',
                onPressed: () {},
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Expand icon (animated)
          TomRow(
            children: [
              TomExpandIcon(
                isExpanded: _isExpanded,
                onPressed: (_) {
                  setState(() => _isExpanded = !_isExpanded);
                },
              ),
              const TomSizedBox(width: 8),
              TomText(
                tomId:
                    _isExpanded ? 'demo01.expand.collapse' : 'demo01.expand.expand',
              ),
            ],
          ),
          const TomSizedBox(height: 24),

          // Context bar example
          TomCard(
            child: TomPadding(
              padding: const EdgeInsets.all(8),
              child: TomRow(
                children: [
                  TomBackButton(
                    tomId: 'demo01.context.back',
                    onPressed: () {},
                  ),
                  const TomExpanded(
                    child: TomCenter(
                      child: TomText(tomId: 'demo01.context.title'),
                    ),
                  ),
                  TomIconButton(
                    tomId: 'demo01.context.more',
                    onPressed: () {},
                  ),
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
      tomId: 'demo01.aclButtons',
      child: AclBuilder()
          // Row 1: Label + Button side by side
          .append(TomText(tomId: 'demo01.aclButtons.primaryLabel'))
          .append(
            TomElevatedButton(
              tomId: 'demo01.aclButtons.primary',
              onPressed: () {},
            ),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 2: Label + Button side by side
          .append(TomText(tomId: 'demo01.aclButtons.secondaryLabel'))
          .append(
            TomOutlinedButton(
              tomId: 'demo01.aclButtons.secondary',
              onPressed: () {},
            ),
            dist: 16,
          )
          .gap()
          .newRow(dist: 16)
          // Row 3: Multiple buttons aligned
          .append(
            TomTextButton(
              tomId: 'demo01.aclButtons.cancel',
              onPressed: () {},
            ),
          )
          .gap()
          .append(
            TomFilledButton(
              tomId: 'demo01.aclButtons.save',
              onPressed: () {},
            ),
            dist: 8,
          )
          .build(),
    );
  }

  Widget _buildAclIconRowSection() {
    return _DemoCard(
      tomId: 'demo01.aclIconRow',
      child: AclBuilder()
          // Row 1: Icon buttons in a row
          .append(TomIconButton(
            tomId: 'demo01.aclIconRow.back',
            onPressed: () {},
          ))
          .append(
            TomText(tomId: 'demo01.aclIconRow.pageTitle'),
            dist: 8,
          )
          .expandX()
          .append(TomIconButton(
            tomId: 'demo01.aclIconRow.settings',
            onPressed: () {},
          ))
          .append(
            TomIconButton(
              tomId: 'demo01.aclIconRow.menu',
              onPressed: () {},
            ),
            dist: 4,
          )
          .newRow(dist: 24)
          // Row 2: FAB row
          .append(TomText(tomId: 'demo01.aclIconRow.fabLabel'))
          .gap()
          .append(
            TomFloatingActionButton.small(
              tomId: 'demo01.aclIconRow.fab',
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
class _SectionHeader extends StatelessWidget {
  final String tomId;

  const _SectionHeader({
    required this.tomId,
  });

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

/// Demo card widget for individual widget showcases.
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
      margin: const EdgeInsets.only(bottom: 16),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with icon
            TomRow(
              children: [
                TomIcon(tomId: '$tomId.icon'),
                const TomSizedBox(width: 12),
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
            const TomSizedBox(height: 8),
            // Description
            TomText(
              tomId: '$tomId.description',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const TomSizedBox(height: 16),
            const TomDivider(),
            const TomSizedBox(height: 16),
            // Widget showcase area
            child,
          ],
        ),
      ),
    );
  }
}
