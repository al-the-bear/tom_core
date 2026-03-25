/// Tom Button Widgets Demo
///
/// This demo showcases all TomButton widgets from tom_flutter_ui with their
/// Tom-specific features:
/// - tomId: Widget identification for tracking/analytics
/// - tomGroup: Group-based visibility and authorization
/// - label: Resource-resolved text (for i18n)
/// - All standard Flutter button parameters
///
/// Each button type is demonstrated with:
/// - Basic usage with Tom features
/// - State variations (enabled, disabled)
/// - Style customization
/// - Icon and label combinations
/// - Group-based visibility control
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Main buttons demo screen with all Tom button categories.
class ButtonsDemo extends StatelessWidget {
  const ButtonsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return TomListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionHeader(
          title: 'TomElevatedButton',
          subtitle: 'Primary action buttons with elevation and shadow',
        ),
        _TomElevatedButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomFilledButton',
          subtitle: 'High-emphasis buttons with filled background (M3)',
        ),
        _TomFilledButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomOutlinedButton',
          subtitle: 'Medium-emphasis buttons with outline border',
        ),
        _TomOutlinedButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomTextButton',
          subtitle: 'Low-emphasis buttons for less prominent actions',
        ),
        _TomTextButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomIconButton',
          subtitle: 'Buttons that display a single icon',
        ),
        _TomIconButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomFloatingActionButton',
          subtitle: 'Circular floating buttons for primary actions',
        ),
        _TomFloatingActionButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomSegmentedButton',
          subtitle: 'Multi-segment toggle buttons (M3)',
        ),
        _TomSegmentedButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomMenuAnchor & TomMenuItemButton',
          subtitle: 'Button-triggered menus with nested items',
        ),
        _TomMenuSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomPopupMenuButton',
          subtitle: 'Buttons that show a popup menu',
        ),
        _TomPopupMenuButtonSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'TomBackButton & TomCloseButton',
          subtitle: 'Specialized navigation buttons',
        ),
        _TomNavigationButtonsSection(),
        TomSizedBox(height: 32),
        _SectionHeader(
          title: 'Group-based Visibility',
          subtitle: 'Control button visibility via tomGroup and TomGroupScope',
        ),
        _GroupVisibilitySection(),
        TomSizedBox(height: 48),
      ],
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TomText(title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const TomSizedBox(height: 4),
        TomText(subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const TomSizedBox(height: 16),
      ],
    );
  }
}

// =============================================================================
// Demo Card Helper
// =============================================================================

Widget _buildDemoCard(String title, String description, Widget child) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return TomCard(
        margin: const EdgeInsets.only(bottom: 16),
        child: TomPadding(
          padding: const EdgeInsets.all(16),
          child: TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomText(title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TomSizedBox(height: 4),
              TomText(description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const TomSizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
    },
  );
}

// =============================================================================
// TomElevatedButton Section
// =============================================================================

class _TomElevatedButtonSection extends StatelessWidget {
  const _TomElevatedButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomElevatedButton',
          'Primary raised button with Tom widget features (tomId, tomGroup).',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                tomId: 'demo.elevated.basic',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.elevated.basic'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.label',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.elevated.label'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.disabled',
                onPressed: null,
                child: const TomText(null, tomId: 'demo.elevated.disabled'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'With Icons',
          'TomElevatedButton with icon parameter for icon+label combo.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                tomId: 'demo.elevated.icon.save',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.elevated.icon.save'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.icon.send',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.elevated.icon.send'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.icon.download',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.elevated.icon.download'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Custom Styles',
          'TomElevatedButton with custom ButtonStyle.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                tomId: 'demo.elevated.style.error',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const TomText(null, tomId: 'demo.elevated.style.error'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.style.rounded',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const TomText(null, tomId: 'demo.elevated.style.rounded'),
              ),
              TomElevatedButton(
                tomId: 'demo.elevated.style.large',
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const TomText(null, tomId: 'demo.elevated.style.large'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomFilledButton Section
// =============================================================================

class _TomFilledButtonSection extends StatelessWidget {
  const _TomFilledButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomFilledButton',
          'M3 filled button with high emphasis.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomFilledButton(
                tomId: 'demo.filled.basic',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.basic'),
              ),
              TomFilledButton(
                tomId: 'demo.filled.label',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.label'),
              ),
              TomFilledButton(
                tomId: 'demo.filled.disabled',
                onPressed: null,
                child: const TomText(null, tomId: 'demo.filled.disabled'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Tonal Variant',
          'TomFilledButton with tonal: true for medium emphasis.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomFilledButton(
                tomId: 'demo.filled.tonal',
                tonal: true,
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.tonal'),
              ),
              TomFilledButton(
                tomId: 'demo.filled.tonal.icon',
                tonal: true,
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.tonal.icon'),
              ),
              TomFilledButton(
                tomId: 'demo.filled.tonal.disabled',
                tonal: true,
                onPressed: null,
                child: const TomText(null, tomId: 'demo.filled.tonal.disabled'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'With Icons',
          'TomFilledButton with icon parameter.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomFilledButton(
                tomId: 'demo.filled.icon.add',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.icon.add'),
              ),
              TomFilledButton(
                tomId: 'demo.filled.icon.share',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.filled.icon.share'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomOutlinedButton Section
// =============================================================================

class _TomOutlinedButtonSection extends StatelessWidget {
  const _TomOutlinedButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomOutlinedButton',
          'Medium-emphasis button with outline border.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomOutlinedButton(
                tomId: 'demo.outlined.basic',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.outlined.basic'),
              ),
              TomOutlinedButton(
                tomId: 'demo.outlined.label',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.outlined.label'),
              ),
              TomOutlinedButton(
                tomId: 'demo.outlined.disabled',
                onPressed: null,
                child: const TomText(null, tomId: 'demo.outlined.disabled'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'With Icons',
          'TomOutlinedButton with icon parameter.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomOutlinedButton(
                tomId: 'demo.outlined.icon.edit',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.outlined.icon.edit'),
              ),
              TomOutlinedButton(
                tomId: 'demo.outlined.icon.cancel',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.outlined.icon.cancel'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Custom Border Styles',
          'TomOutlinedButton with custom borders.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomOutlinedButton(
                tomId: 'demo.outlined.style.thick',
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: const TomText(null, tomId: 'demo.outlined.style.thick'),
              ),
              TomOutlinedButton(
                tomId: 'demo.outlined.style.dashed',
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const TomText(null, tomId: 'demo.outlined.style.dashed'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomTextButton Section
// =============================================================================

class _TomTextButtonSection extends StatelessWidget {
  const _TomTextButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomTextButton',
          'Low-emphasis button for less prominent actions.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomTextButton(
                tomId: 'demo.text.basic',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.basic'),
              ),
              TomTextButton(
                tomId: 'demo.text.label',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.label'),
              ),
              TomTextButton(
                tomId: 'demo.text.disabled',
                onPressed: null,
                child: const TomText(null, tomId: 'demo.text.disabled'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'With Icons',
          'TomTextButton with icon parameter.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomTextButton(
                tomId: 'demo.text.icon.link',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.icon.link'),
              ),
              TomTextButton(
                tomId: 'demo.text.icon.more',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.icon.more'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'In Dialog Actions',
          'Typical usage pattern for dialog buttons.',
          TomRow(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TomTextButton(
                tomId: 'demo.text.dialog.cancel',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.dialog.cancel'),
              ),
              const TomSizedBox(width: 8),
              TomTextButton(
                tomId: 'demo.text.dialog.ok',
                onPressed: () {},
                child: const TomText(null, tomId: 'demo.text.dialog.ok'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomIconButton Section
// =============================================================================

class _TomIconButtonSection extends StatelessWidget {
  const _TomIconButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomIconButton',
          'Icon-only button with tooltip for accessibility.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomIconButton(
                tomId: 'demo.icon.favorite',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo.icon.share',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo.icon.more',
                onPressed: () {},
              ),
              TomIconButton(
                tomId: 'demo.icon.disabled',
                onPressed: null,
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Filled & Tonal Variants',
          'TomIconButton with filled and tonal styles.',
          TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomIconButton.filled(
                tomId: 'demo.icon.filled',
                onPressed: () {},
              ),
              TomIconButton.filledTonal(
                tomId: 'demo.icon.tonal',
                onPressed: () {},
              ),
              TomIconButton.outlined(
                tomId: 'demo.icon.outlined',
                onPressed: () {},
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Custom Sizes',
          'TomIconButton with different icon sizes.',
          TomWrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TomIconButton(
                tomId: 'demo.icon.small',
                onPressed: () {},
                iconSize: 18,
              ),
              TomIconButton(
                tomId: 'demo.icon.medium',
                onPressed: () {},
                iconSize: 24,
              ),
              TomIconButton(
                tomId: 'demo.icon.large',
                onPressed: () {},
                iconSize: 32,
              ),
              TomIconButton(
                tomId: 'demo.icon.xlarge',
                onPressed: () {},
                iconSize: 48,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomFloatingActionButton Section
// =============================================================================

class _TomFloatingActionButtonSection extends StatelessWidget {
  const _TomFloatingActionButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomFloatingActionButton',
          'Primary action FAB with icon.',
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TomFloatingActionButton(
                tomId: 'demo.fab.basic',
                onPressed: () {},
              ),
              TomFloatingActionButton.small(
                tomId: 'demo.fab.small',
                onPressed: () {},
              ),
              TomFloatingActionButton.large(
                tomId: 'demo.fab.large',
                onPressed: () {},
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Extended FAB',
          'FAB with icon and label.',
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomFloatingActionButton.extended(
                tomId: 'demo.fab.extended.compose',
                onPressed: () {},
              ),
              TomFloatingActionButton.extended(
                tomId: 'demo.fab.extended.add',
                onPressed: () {},
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Custom Colors',
          'FAB with custom background and foreground colors.',
          TomWrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              TomFloatingActionButton(
                tomId: 'demo.fab.color.tertiary',
                onPressed: () {},
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              TomFloatingActionButton(
                tomId: 'demo.fab.color.error',
                onPressed: () {},
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomSegmentedButton Section
// =============================================================================

class _TomSegmentedButtonSection extends StatefulWidget {
  const _TomSegmentedButtonSection();

  @override
  State<_TomSegmentedButtonSection> createState() =>
      _TomSegmentedButtonSectionState();
}

class _TomSegmentedButtonSectionState
    extends State<_TomSegmentedButtonSection> {
  Set<String> _singleSelection = {'day'};
  Set<String> _multiSelection = {'bold'};

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Single Selection',
          'TomSegmentedButton with single selection (Calendar view toggle).',
          TomSegmentedButton<String>(
            tomId: 'demo.segmented.single',
            segments: const [
              ButtonSegment(
                value: 'day',
                icon: TomIcon(Icons.calendar_view_day),
                label: TomText(null, tomId: 'demo.segmented.day'),
              ),
              ButtonSegment(
                value: 'week',
                icon: TomIcon(Icons.calendar_view_week),
                label: TomText(null, tomId: 'demo.segmented.week'),
              ),
              ButtonSegment(
                value: 'month',
                icon: TomIcon(Icons.calendar_view_month),
                label: TomText(null, tomId: 'demo.segmented.month'),
              ),
            ],
            selected: _singleSelection,
            onSelectionChanged: (selection) {
              setState(() => _singleSelection = selection);
            },
          ),
        ),
        _buildDemoCard(
          'Multi Selection',
          'TomSegmentedButton with multiSelectionEnabled for text formatting.',
          TomSegmentedButton<String>(
            tomId: 'demo.segmented.multi',
            multiSelectionEnabled: true,
            segments: const [
              ButtonSegment(
                value: 'bold',
                icon: TomIcon(Icons.format_bold),
                label: TomText(null, tomId: 'demo.segmented.bold'),
              ),
              ButtonSegment(
                value: 'italic',
                icon: TomIcon(Icons.format_italic),
                label: TomText(null, tomId: 'demo.segmented.italic'),
              ),
              ButtonSegment(
                value: 'underline',
                icon: TomIcon(Icons.format_underline),
                label: TomText(null, tomId: 'demo.segmented.underline'),
              ),
            ],
            selected: _multiSelection,
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              setState(() => _multiSelection = selection);
            },
          ),
        ),
        _buildDemoCard(
          'Icon Only',
          'TomSegmentedButton with icons only (no labels).',
          TomSegmentedButton<String>(
            tomId: 'demo.segmented.icons',
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'list',
                icon: TomIcon(Icons.view_list),
              ),
              ButtonSegment(
                value: 'grid',
                icon: TomIcon(Icons.grid_view),
              ),
              ButtonSegment(
                value: 'module',
                icon: TomIcon(Icons.view_module),
              ),
            ],
            selected: const {'list'},
            onSelectionChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomMenuAnchor & TomMenuItemButton Section
// =============================================================================

class _TomMenuSection extends StatelessWidget {
  const _TomMenuSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'TomMenuAnchor with TomMenuItemButton',
          'Dropdown menu with menu items using Tom widgets.',
          TomMenuAnchor(
            tomId: 'demo.menu.anchor',
            menuChildren: [
              TomMenuItemButton(
                tomId: 'demo.menu.item.cut',
                onPressed: () {},
                leadingIcon: const TomIcon(Icons.cut),
                child: const TomText(null, tomId: 'demo.menu.item.cut'),
              ),
              TomMenuItemButton(
                tomId: 'demo.menu.item.copy',
                onPressed: () {},
                leadingIcon: const TomIcon(Icons.copy),
                child: const TomText(null, tomId: 'demo.menu.item.copy'),
              ),
              TomMenuItemButton(
                tomId: 'demo.menu.item.paste',
                onPressed: () {},
                leadingIcon: const TomIcon(Icons.paste),
                child: const TomText(null, tomId: 'demo.menu.item.paste'),
              ),
              const TomDivider(),
              TomMenuItemButton(
                tomId: 'demo.menu.item.selectall',
                onPressed: () {},
                leadingIcon: const TomIcon(Icons.select_all),
                child: const TomText(null, tomId: 'demo.menu.item.selectall'),
              ),
            ],
            builder: (context, controller, child) {
              return TomElevatedButton(
                tomId: 'demo.menu.trigger',
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: const TomText(null, tomId: 'demo.menu.trigger'),
              );
            },
          ),
        ),
        _buildDemoCard(
          'TomSubmenuButton (Nested Menus)',
          'Menu with nested submenu using TomSubmenuButton.',
          TomMenuAnchor(
            tomId: 'demo.submenu.anchor',
            menuChildren: [
              TomMenuItemButton(
                tomId: 'demo.submenu.new',
                onPressed: () {},
                leadingIcon: const TomIcon(Icons.add),
                child: const TomText(null, tomId: 'demo.submenu.new'),
              ),
              TomSubmenuButton(
                tomId: 'demo.submenu.open',
                leadingIcon: const TomIcon(Icons.folder_open),
                menuChildren: [
                  TomMenuItemButton(
                    tomId: 'demo.submenu.open.recent',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.submenu.open.recent'),
                  ),
                  TomMenuItemButton(
                    tomId: 'demo.submenu.open.browse',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.submenu.open.browse'),
                  ),
                ],
                child: const TomText(null, tomId: 'demo.submenu.open'),
              ),
              TomSubmenuButton(
                tomId: 'demo.submenu.export',
                leadingIcon: const TomIcon(Icons.ios_share),
                menuChildren: [
                  TomMenuItemButton(
                    tomId: 'demo.submenu.export.pdf',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.submenu.export.pdf'),
                  ),
                  TomMenuItemButton(
                    tomId: 'demo.submenu.export.csv',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.submenu.export.csv'),
                  ),
                  TomMenuItemButton(
                    tomId: 'demo.submenu.export.json',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.submenu.export.json'),
                  ),
                ],
                child: const TomText(null, tomId: 'demo.submenu.export'),
              ),
            ],
            builder: (context, controller, child) {
              return TomFilledButton(
                tomId: 'demo.submenu.trigger',
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: const TomText(null, tomId: 'demo.submenu.trigger'),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TomPopupMenuButton Section
// =============================================================================

class _TomPopupMenuButtonSection extends StatelessWidget {
  const _TomPopupMenuButtonSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'Basic TomPopupMenuButton',
          'Popup menu button with TomPopupMenuItem entries.',
          TomPopupMenuButton<String>(
            tomId: 'demo.popup.basic',
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                TomSnackBar(content: TomText('Selected: $value')),
              );
            },
            itemBuilder: (context) => [
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.item.view',
                value: 'view',
                child: const TomText(null, tomId: 'demo.popup.item.view'),
              ),
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.item.edit',
                value: 'edit',
                child: const TomText(null, tomId: 'demo.popup.item.edit'),
              ),
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.item.delete',
                value: 'delete',
                child: const TomText(null, tomId: 'demo.popup.item.delete'),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'With Icons and Dividers',
          'TomPopupMenuButton with icons and TomPopupMenuDivider.',
          TomPopupMenuButton<String>(
            tomId: 'demo.popup.icons',
            icon: const TomIcon(Icons.more_vert),
            onSelected: (value) {},
            itemBuilder: (context) => [
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.icons.share',
                value: 'share',
                child: const TomRow(
                  children: [
                    TomIcon(Icons.share, size: 20),
                    TomSizedBox(width: 12),
                    TomText(null, tomId: 'demo.popup.icons.share'),
                  ],
                ),
              ),
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.icons.link',
                value: 'link',
                child: const TomRow(
                  children: [
                    TomIcon(Icons.link, size: 20),
                    TomSizedBox(width: 12),
                    TomText(null, tomId: 'demo.popup.icons.link'),
                  ],
                ),
              ),
              const TomPopupMenuDivider(tomId: 'demo.popup.divider'),
              TomPopupMenuItem<String>(
                tomId: 'demo.popup.icons.report',
                value: 'report',
                child: TomRow(
                  children: [
                    TomIcon(Icons.flag, size: 20, color: Colors.red.shade700),
                    const TomSizedBox(width: 12),
                    TomText(null, tomId: 'demo.popup.icons.report',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'TomCheckedPopupMenuItem',
          'Popup menu with checkable items.',
          _CheckedPopupMenuDemo(),
        ),
      ],
    );
  }
}

class _CheckedPopupMenuDemo extends StatefulWidget {
  @override
  State<_CheckedPopupMenuDemo> createState() => _CheckedPopupMenuDemoState();
}

class _CheckedPopupMenuDemoState extends State<_CheckedPopupMenuDemo> {
  bool _showImages = true;
  bool _showVideos = true;
  bool _showDocuments = false;

  @override
  Widget build(BuildContext context) {
    return TomPopupMenuButton<String>(
      tomId: 'demo.popup.checked',
      child: const TomRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          TomIcon(Icons.filter_list),
          TomSizedBox(width: 8),
          TomText(null, tomId: 'demo.popup.filter'),
          TomIcon(Icons.arrow_drop_down),
        ],
      ),
      itemBuilder: (context) => [
        TomCheckedPopupMenuItem<String>(
          tomId: 'demo.popup.checked.images',
          value: 'images',
          checked: _showImages,
          child: const TomText(null, tomId: 'demo.popup.checked.images'),
        ),
        TomCheckedPopupMenuItem<String>(
          tomId: 'demo.popup.checked.videos',
          value: 'videos',
          checked: _showVideos,
          child: const TomText(null, tomId: 'demo.popup.checked.videos'),
        ),
        TomCheckedPopupMenuItem<String>(
          tomId: 'demo.popup.checked.documents',
          value: 'documents',
          checked: _showDocuments,
          child: const TomText(null, tomId: 'demo.popup.checked.documents'),
        ),
      ],
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'images':
              _showImages = !_showImages;
            case 'videos':
              _showVideos = !_showVideos;
            case 'documents':
              _showDocuments = !_showDocuments;
          }
        });
      },
    );
  }
}

// =============================================================================
// TomBackButton & TomCloseButton Section
// =============================================================================

class _TomNavigationButtonsSection extends StatelessWidget {
  const _TomNavigationButtonsSection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'TomBackButton',
          'Platform-aware back navigation button.',
          TomRow(
            children: [
              TomBackButton(
                tomId: 'demo.back.default',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    TomSnackBar(content: TomText('Back pressed')),
                  );
                },
              ),
              const TomSizedBox(width: 16),
              const TomText('← TomBackButton triggers navigation'),
            ],
          ),
        ),
        _buildDemoCard(
          'TomCloseButton',
          'Close button for dialogs and panels.',
          TomRow(
            children: [
              TomCloseButton(
                tomId: 'demo.close.default',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    TomSnackBar(content: TomText('Close pressed')),
                  );
                },
              ),
              const TomSizedBox(width: 16),
              const TomText('← TomCloseButton for dismissing content'),
            ],
          ),
        ),
        _buildDemoCard(
          'In Context',
          'These buttons used in typical scenarios.',
          TomColumn(
            children: [
              // Simulated app bar with back button
              TomContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomRow(
                  children: [
                    TomBackButton(
                      tomId: 'demo.context.back',
                      onPressed: () {},
                    ),
                    const TomSizedBox(width: 8),
                    TomExpanded(
                      tomId: 'demo.context.detail.label',
                      child: TomText('Detail Page'),
                    ),
                    TomIconButton(
                      tomId: 'demo.context.more',
                      icon: const TomIcon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const TomSizedBox(height: 16),
              // Simulated dialog header with close button
              TomContainer(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TomRow(
                      children: [
                        TomExpanded(
                          tomId: 'demo.context.settings.label',
                          child: TomText('Settings',
                            
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TomCloseButton(
                          tomId: 'demo.context.close',
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const TomSizedBox(height: 8),
                    const TomText('Dialog or panel content goes here...'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Group-based Visibility Section
// =============================================================================

class _GroupVisibilitySection extends StatelessWidget {
  const _GroupVisibilitySection();

  @override
  Widget build(BuildContext context) {
    return TomColumn(
      children: [
        _buildDemoCard(
          'TomGroupScope Demo',
          'Buttons with tomGroup parameter for authorization-based visibility.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TomText(
                'Buttons can specify a tomGroup for authorization control. '
                    'When wrapped in TomGroupScope, visibility is managed by the auth system.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const TomSizedBox(height: 16),

              // Admin-only buttons (shown as examples)
              TomWrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TomElevatedButton(
                    tomId: 'demo.group.btn.delete',
                    tomGroup: 'admin',
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                      foregroundColor:
                          Theme.of(context).colorScheme.onError,
                    ),
                    child: const TomText(null, tomId: 'demo.group.btn.delete'),
                  ),
                  TomElevatedButton(
                    tomId: 'demo.group.btn.settings',
                    tomGroup: 'admin',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.group.btn.settings'),
                  ),

                  // Editor buttons
                  TomFilledButton(
                    tomId: 'demo.group.btn.edit',
                    tomGroup: 'editor',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.group.btn.edit'),
                  ),
                  TomFilledButton(
                    tomId: 'demo.group.btn.publish',
                    tomGroup: 'editor',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.group.btn.publish'),
                  ),

                  // Viewer buttons
                  TomOutlinedButton(
                    tomId: 'demo.group.btn.view',
                    tomGroup: 'viewer',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.group.btn.view'),
                  ),
                  TomOutlinedButton(
                    tomId: 'demo.group.btn.download',
                    tomGroup: 'viewer',
                    onPressed: () {},
                    child: const TomText(null, tomId: 'demo.group.btn.download'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDemoCard(
          'Group Authorization Info',
          'How group-based visibility works.',
          TomColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TomContainer(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TomRow(
                  children: [
                    TomIcon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const TomSizedBox(width: 12),
                    TomExpanded(
                      child: TomText(
                        'Buttons use tomGroup to specify their required '
                        'permission group. TomGroupScope defines group boundaries '
                        'and the auth system controls visibility.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
