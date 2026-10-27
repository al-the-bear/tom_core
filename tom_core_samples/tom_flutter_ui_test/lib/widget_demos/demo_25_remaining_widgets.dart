/// Demo 25: Dialogs, Buttons, Navigation, Labels, Lists & Images
///
/// Demonstrates remaining Tom widgets not covered in previous demos.
///
/// Widgets covered: TomSnackBarAction,
/// TomDropdownMenuEntry, TomCupertinoActionSheetAction,
/// TomCupertinoDialogAction, TomCupertinoContextMenuAction,
/// TomDialog, TomAboutDialog, TomSimpleDialogOption,
/// TomDateRangePickerDialog, TomTimePickerDialog,
/// TomCupertinoContextMenu, TomLicensePage,
/// TomAboutListTile, TomBanner, TomMenuAcceleratorLabel,
/// TomBreadcrumb, TomDrawerHeader, TomUserAccountsDrawerHeader,
/// TomFlexibleSpaceBar, TomTabPageSelector, TomCupertinoNavigationBarBackButton,
/// TomCupertinoSliverNavigationBar,
/// TomAssetImage, TomFileImage, TomInkImage,
/// TomCupertinoListSection, TomCupertinoListTile,
/// TomReorderableList, TomSliverReorderableList.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// =============================================================================
// Main Demo Page
// =============================================================================

/// Main entry point for the remaining widgets demo.
class RemainingWidgetsDemo extends TomStatelessWidget {
  RemainingWidgetsDemo({super.key});

  @override
  Widget buildContent(BuildContext context) {
    return _RemainingWidgetsDemoContent();
  }
}

class _RemainingWidgetsDemoContent extends TomStatefulWidget {
  _RemainingWidgetsDemoContent();

  @override
  State<_RemainingWidgetsDemoContent> createState() =>
      _RemainingWidgetsDemoContentState();
}

class _RemainingWidgetsDemoContentState
    extends TomState<_RemainingWidgetsDemoContent>
    with TickerProviderStateMixin {
  // For TabPageSelector
  late TabController _tabPageController;

  // For reorderable list
  final List<String> _reorderItems = List.generate(
    5,
    (i) => 'Reorderable Item ${i + 1}',
  );

  // For DropdownMenuEntry demo
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _tabPageController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return TomSingleChildScrollView(
      child: TomPadding(
        padding: const EdgeInsets.all(24),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Button Extras
            _SectionHeader(tomId: 'section.buttonExtras'),
            TomSizedBox(height: 16),
            _buildButtonExtrasSection(context),
            TomSizedBox(height: 32),

            // Section 2: Dialog Extras
            _SectionHeader(tomId: 'section.dialogExtras'),
            TomSizedBox(height: 16),
            _buildDialogExtrasSection(context),
            TomSizedBox(height: 32),

            // Section 3: Label Extras
            _SectionHeader(tomId: 'section.labelExtras'),
            TomSizedBox(height: 16),
            _buildLabelExtrasSection(context),
            TomSizedBox(height: 32),

            // Section 4: Navigation Extras
            _SectionHeader(tomId: 'section.navExtras'),
            TomSizedBox(height: 16),
            _buildNavigationExtrasSection(context),
            TomSizedBox(height: 32),

            // Section 5: Image Extras
            _SectionHeader(tomId: 'section.imageExtras'),
            TomSizedBox(height: 16),
            _buildImageExtrasSection(context),
            TomSizedBox(height: 32),

            // Section 6: List Extras
            _SectionHeader(tomId: 'section.listExtras'),
            TomSizedBox(height: 16),
            _buildListExtrasSection(context),
            TomSizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Section 1: Button Extras
  // ===========================================================================

  Widget _buildButtonExtrasSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomDropdownMenuEntry (inside TomDropdownMenu)
        _DemoCard(
          tomId: 'demo.dropdownMenuEntry',
          child: Builder(
            builder: (context) {
              final entries = [
                TomDropdownMenuEntry<String>(
                  tomId: 'entry.red',
                  value: 'red',
                  label: 'Red',
                  leadingIcon: Icon(Icons.circle, color: Colors.red.shade400),
                ),
                TomDropdownMenuEntry<String>(
                  tomId: 'entry.green',
                  value: 'green',
                  label: 'Green',
                  leadingIcon: Icon(Icons.circle, color: Colors.green.shade400),
                ),
                TomDropdownMenuEntry<String>(
                  tomId: 'entry.blue',
                  value: 'blue',
                  label: 'Blue',
                  leadingIcon: Icon(Icons.circle, color: Colors.blue.shade400),
                ),
              ];
              return TomDropdownMenu<String>(
                tomId: 'dropdownMenuEntry.demo',
                label: 'Select color',
                initialSelection: _selectedColor,
                onSelected: (value) => setState(() => _selectedColor = value),
                dropdownMenuEntries: entries
                    .map((e) => e.toEntry(context))
                    .toList(),
              );
            },
          ),
        ),
        TomSizedBox(height: 16),

        // TomSnackBarAction (shown via button)
        _DemoCard(
          tomId: 'demo.snackBarAction',
          child: TomElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                TomSnackBar(
                  tomId: 'snackBar.demo',
                  content: const Text('TomSnackBar with TomSnackBarAction'),
                  action: TomSnackBarAction(
                    tomId: 'snackBarAction.demo',
                    label: 'Undo',
                    onPressed: () {},
                  ),
                ),
              );
            },
            child: const Text('Show SnackBar with TomSnackBarAction'),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 2: Dialog Extras
  // ===========================================================================

  Widget _buildDialogExtrasSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DemoCard(
          tomId: 'demo.dialogs',
          child: TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // TomDialog
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TomDialog(
                      tomId: 'dialog.basic',
                      child: TomPadding(
                        padding: const EdgeInsets.all(24),
                        child: TomColumn(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('TomDialog (base)'),
                            TomSizedBox(height: 16),
                            TomElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('TomDialog'),
              ),

              // TomAboutDialog
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TomAboutDialog(
                      tomId: 'about.demo',
                      applicationName: 'Tom Flutter UI',
                      applicationVersion: '1.0.0',
                      applicationIcon: const FlutterLogo(size: 48),
                      applicationLegalese: '(c) 2026 Tom',
                    ),
                  );
                },
                child: const Text('TomAboutDialog'),
              ),

              // TomSimpleDialogOption
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TomSimpleDialog(
                      tomId: 'simpleDialog.demo',
                      title: const Text('Choose an option'),
                      children: [
                        TomSimpleDialogOption(
                          tomId: 'option.1',
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Option 1'),
                        ),
                        TomSimpleDialogOption(
                          tomId: 'option.2',
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Option 2'),
                        ),
                        TomSimpleDialogOption(
                          tomId: 'option.3',
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Option 3'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('SimpleDialogOption'),
              ),

              // TomDateRangePickerDialog
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TomDateRangePickerDialog(
                      tomId: 'dateRange.demo',
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    ),
                  );
                },
                child: const Text('DateRangePicker'),
              ),

              // TomTimePickerDialog
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => TomTimePickerDialog(
                      tomId: 'timePicker.demo',
                      initialTime: TimeOfDay.now(),
                    ),
                  );
                },
                child: const Text('TimePicker'),
              ),

              // TomCupertinoContextMenu
              TomElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Center(
                      child: TomCupertinoContextMenu(
                        tomId: 'cupertinoContext.demo',
                        actions: [
                          TomCupertinoContextMenuAction(
                            tomId: 'ctxAction.copy',
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Copy'),
                          ),
                          TomCupertinoContextMenuAction(
                            tomId: 'ctxAction.delete',
                            isDestructiveAction: true,
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Delete'),
                          ),
                        ],
                        child: TomContainer(
                          width: 200,
                          height: 100,
                          color: Colors.blue.shade200,
                          child: const Center(
                            child: Text('Long press for context menu'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('CupertinoContext'),
              ),

              // TomLicensePage (navigates)
              TomElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TomLicensePage(
                        tomId: 'licensePage.demo',
                        applicationName: 'Tom Flutter UI',
                        applicationVersion: '1.0.0',
                      ),
                    ),
                  );
                },
                child: const Text('LicensePage'),
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // Cupertino dialog actions
        _DemoCard(
          tomId: 'demo.cupertinoDialogActions',
          child: TomWrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TomElevatedButton(
                onPressed: () {
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('Cupertino Dialog'),
                      content: const Text('With TomCupertinoDialogAction'),
                      actions: [
                        TomCupertinoDialogAction(
                          tomId: 'cupertinoDlgAction.cancel',
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TomCupertinoDialogAction(
                          tomId: 'cupertinoDlgAction.ok',
                          isDefaultAction: true,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('CupertinoDialogAction'),
              ),
              TomElevatedButton(
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (ctx) => TomCupertinoActionSheet(
                      tomId: 'actionSheet.demo',
                      title: const Text('Action Sheet'),
                      message: const Text('With TomCupertinoActionSheetAction'),
                      actions: [
                        TomCupertinoActionSheetAction(
                          tomId: 'sheetAction.share',
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Share'),
                        ),
                        TomCupertinoActionSheetAction(
                          tomId: 'sheetAction.delete',
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Delete'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                },
                child: const Text('ActionSheetAction'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 3: Label Extras
  // ===========================================================================

  Widget _buildLabelExtrasSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomAboutListTile
        _DemoCard(
          tomId: 'demo.aboutListTile',
          child: TomAboutListTile(
            tomId: 'aboutListTile.demo',
            icon: const Icon(Icons.info),
            applicationName: 'Tom Flutter UI',
            applicationVersion: '1.0.0',
            applicationIcon: const FlutterLogo(size: 48),
            applicationLegalese: '(c) 2026 Tom',
            child: const Text('About'),
          ),
        ),
        TomSizedBox(height: 16),

        // TomBanner
        _DemoCard(
          tomId: 'demo.banner',
          child: TomSizedBox(
            height: 100,
            child: TomStack(
              children: [
                TomContainer(
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('Content behind banner')),
                ),
                TomBanner(
                  tomId: 'banner.demo',
                  message: 'BETA',
                  location: BannerLocation.topEnd,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomMenuAcceleratorLabel
        _DemoCard(
          tomId: 'demo.menuAccelerator',
          child: TomContainer(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TomColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TomMenuAcceleratorLabel renders keyboard accelerator '
                  'hints in menu items (underlined character). '
                  'Only visible inside MenuBar/MenuAnchor context.',
                ),
                TomSizedBox(height: 8),
                TomMenuAcceleratorLabel(
                  tomId: 'menuAccelerator.demo',
                  label: '&File',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 4: Navigation Extras
  // ===========================================================================

  Widget _buildNavigationExtrasSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomBreadcrumb
        _DemoCard(
          tomId: 'demo.breadcrumb',
          child: TomBreadcrumb(
            tomId: 'breadcrumb.demo',
            items: [
              TextButton(onPressed: () {}, child: const Text('Home')),
              TextButton(onPressed: () {}, child: const Text('Products')),
              const Text('Widget Library'),
            ],
            separator: const Icon(Icons.chevron_right, size: 16),
          ),
        ),
        TomSizedBox(height: 16),

        // TomDrawerHeader + TomUserAccountsDrawerHeader
        _DemoCard(
          tomId: 'demo.drawerHeaders',
          child: TomSizedBox(
            width: 280,
            child: TomColumn(
              children: [
                TomDrawerHeader(
                  tomId: 'drawerHeader.demo',
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: const Text('TomDrawerHeader'),
                ),
                TomSizedBox(height: 8),
                TomUserAccountsDrawerHeader(
                  tomId: 'userAccounts.demo',
                  accountName: const Text('Tom User'),
                  accountEmail: const Text('tom@example.com'),
                  currentAccountPicture: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomFlexibleSpaceBar (inside SliverAppBar)
        _DemoCard(
          tomId: 'demo.flexibleSpaceBar',
          child: TomSizedBox(
            height: 250,
            child: TomCustomScrollView(
              slivers: [
                TomSliverAppBar(
                  tomId: 'sliverAppBar.flexDemo',
                  expandedHeight: 150,
                  pinned: true,
                  flexibleSpace: TomFlexibleSpaceBar(
                    tomId: 'flexibleSpace.demo',
                    title: const Text(
                      'Flexible Space',
                      style: TextStyle(fontSize: 14),
                    ),
                    background: TomContainer(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Center(
                        child: Icon(Icons.landscape, size: 64),
                      ),
                    ),
                  ),
                ),
                TomSliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ListTile(title: Text('Item $index')),
                    childCount: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        TomSizedBox(height: 16),

        // TomTabPageSelector
        _DemoCard(
          tomId: 'demo.tabPageSelector',
          child: TomColumn(
            children: [
              TomTabPageSelector(
                tomId: 'tabPageSelector.demo',
                controller: _tabPageController,
                color: Colors.grey.shade300,
                selectedColor: Theme.of(context).colorScheme.primary,
              ),
              TomSizedBox(height: 8),
              TomSizedBox(
                height: 80,
                child: TabBarView(
                  controller: _tabPageController,
                  children: List.generate(
                    4,
                    (i) => Center(child: Text('Page ${i + 1}')),
                  ),
                ),
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // TomCupertinoNavigationBarBackButton + TomCupertinoSliverNavigationBar
        _DemoCard(
          tomId: 'demo.cupertinoNavExtras',
          child: TomSizedBox(
            height: 260,
            child: CupertinoApp(
              debugShowCheckedModeBanner: false,
              home: CupertinoPageScaffold(
                child: CustomScrollView(
                  slivers: [
                    TomCupertinoSliverNavigationBar(
                      tomId: 'cupertinoSliverNav.demo',
                      largeTitle: const Text('Cupertino'),
                      leading: TomCupertinoNavigationBarBackButton(
                        tomId: 'cupertinoBack.demo',
                        previousPageTitle: 'Back',
                        onPressed: () {},
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => CupertinoListTile(
                          title: Text('Cupertino Item $index'),
                        ),
                        childCount: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section 5: Image Extras
  // ===========================================================================

  Widget _buildImageExtrasSection(BuildContext context) {
    return _DemoCard(
      tomId: 'demo.imageExtras',
      child: TomContainer(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
                TomSizedBox(width: 8),
                TomExpanded(
                  child: Text(
                    'Image Widgets',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 12),
            const Text(
              'Three additional image widgets for specialized sources:',
            ),
            TomSizedBox(height: 8),
            _buildImageInfoRow(
              context,
              'TomAssetImage',
              'Loads images from asset bundles (name: \'assets/photo.png\')',
            ),
            _buildImageInfoRow(
              context,
              'TomFileImage',
              'Loads images from file paths (filePath: \'/path/to/image.jpg\')',
            ),
            _buildImageInfoRow(
              context,
              'TomInkImage',
              'Image with ink splash effects (image: AssetImage(...))',
            ),
            TomSizedBox(height: 8),
            const Text(
              'These extend the image coverage from demo_12 (TomImage, '
              'TomNetworkImage, TomCircleAvatar, TomFadeInImage, etc.).\n'
              'They require actual image files to display correctly.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageInfoRow(
    BuildContext context,
    String name,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TomRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 20),
          TomSizedBox(width: 4),
          TomExpanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$name — ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 6: List Extras
  // ===========================================================================

  Widget _buildListExtrasSection(BuildContext context) {
    return TomColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TomCupertinoListSection + TomCupertinoListTile
        _DemoCard(
          tomId: 'demo.cupertinoList',
          child: TomCupertinoListSection(
            tomId: 'cupertinoListSection.demo',
            header: const Text('Cupertino List'),
            children: [
              TomCupertinoListTile(
                tomId: 'cupertinoTile.1',
                title: const Text('Wi-Fi'),
                leading: const Icon(CupertinoIcons.wifi, color: Colors.blue),
                trailing: const CupertinoSwitch(value: true, onChanged: null),
              ),
              TomCupertinoListTile(
                tomId: 'cupertinoTile.2',
                title: const Text('Bluetooth'),
                leading: const Icon(
                  CupertinoIcons.bluetooth,
                  color: Colors.blue,
                ),
                trailing: const CupertinoSwitch(value: false, onChanged: null),
              ),
              TomCupertinoListTile(
                tomId: 'cupertinoTile.3',
                title: const Text('Notifications'),
                leading: const Icon(CupertinoIcons.bell, color: Colors.red),
                trailing: const CupertinoListTileChevron(),
              ),
            ],
          ),
        ),
        TomSizedBox(height: 16),

        // TomReorderableList
        _DemoCard(
          tomId: 'demo.reorderableList',
          child: TomSizedBox(
            height: 250,
            child: TomReorderableListView(
              tomId: 'reorderableList.demo',
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _reorderItems.removeAt(oldIndex);
                  _reorderItems.insert(newIndex, item);
                });
              },
              children: _reorderItems
                  .map(
                    (item) => ListTile(
                      key: ValueKey(item),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(item),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared Helpers
// =============================================================================

/// Section header with title and subtitle from resources.
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

/// Demo card with title, subtitle, and icon from resources.
class _DemoCard extends TomStatelessWidget {
  final String tomId;
  final Widget child;

  _DemoCard({required this.tomId, required this.child});

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: TomPadding(
        padding: const EdgeInsets.all(16),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TomRow(
              children: [
                TomIcon(tomId: tomId, size: 24),
                TomSizedBox(width: 12),
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
                        tomId: '$tomId.subtitle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TomSizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
