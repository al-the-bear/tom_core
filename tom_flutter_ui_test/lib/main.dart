/// Tom Flutter UI Test Application
///
/// A comprehensive demo app showcasing all tom_flutter_ui widgets and features.
/// The app is organized into multiple tabs:
/// - ACL Demos: Advanced Container Layout system demos
/// - Widget Demos: Individual widget showcases (20 categories)
/// - Roadmap: Future development plans
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'acl_demos/acl_demos.dart';
import 'common/demo_scaffold.dart';
import 'demo_resources.dart';
import 'locale_settings.dart';
import 'widget_demos/demo_01_buttons.dart';
import 'widget_demos/demo_02_inputs.dart';
import 'widget_demos/demo_03_selection.dart';
import 'widget_demos/demo_04_toggles.dart';
import 'widget_demos/demo_05_sliders.dart';
import 'widget_demos/demo_06_cards_panels.dart';
import 'widget_demos/demo_07_layout.dart';
import 'widget_demos/demo_08_scrollable.dart';
import 'widget_demos/demo_09_dialogs.dart';
import 'widget_demos/demo_10_tables.dart';
import 'widget_demos/demo_11_labels.dart';
import 'widget_demos/demo_12_images.dart';
import 'widget_demos/demo_13_navigation.dart';
import 'widget_demos/demo_14_progress.dart';
import 'widget_demos/demo_15_lists.dart';
import 'widget_demos/demo_16_trees.dart';
import 'widget_demos/demo_17_slivers.dart';
import 'widget_demos/demo_18_animated.dart';
import 'widget_demos/demo_19_effects.dart';
import 'widget_demos/demo_20_interactions.dart';
import 'widget_demos/demo_21_resource_resolution.dart';

/// Global locale settings service instance.
final localeSettingsService = LocaleSettingsService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Tom UI resource and icon adapters
  initializeDemoResources();

  // Load saved locale preference
  await localeSettingsService.initialize();

  runApp(const TomFlutterUiTestApp());
}

/// Main application widget.
class TomFlutterUiTestApp extends StatefulWidget {
  const TomFlutterUiTestApp({super.key});

  @override
  State<TomFlutterUiTestApp> createState() => _TomFlutterUiTestAppState();
}

class _TomFlutterUiTestAppState extends State<TomFlutterUiTestApp> {
  @override
  void initState() {
    super.initState();
    localeSettingsService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeSettingsService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Flutter UI Test',
      debugShowCheckedModeBanner: false,
      // Localization configuration
      locale: localeSettingsService.locale,
      supportedLocales: AppLocales.locales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainTabsPage(),
    );
  }
}

/// Main page with tabs for different demo categories.
class MainTabsPage extends StatelessWidget {
  const MainTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tom Flutter UI'),
          actions: [
            LanguageSelectorButton(localeService: localeSettingsService),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_view), text: 'ACL Demos'),
              Tab(icon: Icon(Icons.widgets), text: 'Widget Demos'),
              Tab(icon: Icon(Icons.map), text: 'Roadmap'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AclDemosTab(),
            WidgetDemosTab(),
            RoadmapTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ACL Demos Tab
// ---------------------------------------------------------------------------

/// Tab showing all ACL (Advanced Container Layout) demos.
class AclDemosTab extends StatelessWidget {
  const AclDemosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        DemoTile(
          title: 'Basic Row Layout',
          description: 'Simple horizontal arrangement of components',
          screen: BasicRowDemo(),
        ),
        DemoTile(
          title: 'Multiple Rows',
          description: 'Vertical stacking with newRow()',
          screen: MultiRowDemo(),
        ),
        DemoTile(
          title: 'Row Alignment',
          description: 'LEFT, CENTER, RIGHT alignment',
          screen: AlignmentDemo(),
        ),
        DemoTile(
          title: 'All Dimensions',
          description: 'Full-window layout: expandX + expandY + both combined',
          fullScreen: true,
          screen: AllDimensionsDemo(),
        ),
        DemoTile(
          title: 'Expand Flags',
          description: 'EXPANDX, EXPANDY for flexible layouts',
          screen: ExpandDemo(),
        ),
        DemoTile(
          title: 'Spacing & Gaps',
          description: 'Component and row spacing',
          screen: SpacingDemo(),
        ),
        DemoTile(
          title: 'Size Constraints',
          description: 'Minimum, preferred and maximum size behavior',
          screen: SizeConstraintsDemo(),
        ),
        DemoTile(
          title: 'Reference Constraints',
          description:
              'same-size plus left/right/center/vertical alignment to references',
          screen: ReferenceConstraintsDemo(),
        ),
        DemoTile(
          title: 'Cross-Row Alignment',
          description:
              'Reference other rows: alignTopToBottom, alignRightToRight, etc.',
          screen: ConveniencePlacementDemo(),
        ),
        DemoTile(
          title: 'Mixed Placement Playground',
          description:
              'Cross-row alignment combined with regular rows, sameSize, expandX',
          screen: MixedPlacementPlaygroundDemo(),
        ),
        DemoTile(
          title: 'Responsive Layout',
          description:
              'Shrink/grow between preferred and minimum sizes as the window resizes',
          screen: ResponsiveConvenienceDemo(),
        ),
        DemoTile(
          title: 'Character Width Sizing',
          description:
              'setPWidthInChars / setMWidthInChars / setXWidthInChars for character-based field widths',
          screen: CharacterWidthSizingDemo(),
        ),
        DemoTile(
          title: 'Border Styles',
          description: 'Various border styles and border inset examples',
          screen: BorderStylesDemo(),
        ),
        DemoTile(
          title: 'Groups (Titled Borders)',
          description: 'Group boxes with titles',
          screen: GroupsDemo(),
        ),
        DemoTile(
          title: 'Bordered Groups',
          description:
              'Single-line borders with topLeft / topCenter / topRight titles',
          screen: BorderedGroupsDemo(),
        ),
        DemoTile(
          title: 'Nested Containers',
          description: 'Containers within containers',
          screen: NestedContainersDemo(),
        ),
        DemoTile(
          title: 'Form Layout',
          description: 'Typical form layout pattern',
          screen: FormLayoutDemo(),
        ),
        DemoTile(
          title: 'Complex Layout',
          description: 'Combined features demonstration',
          screen: ComplexLayoutDemo(),
        ),
        DemoTile(
          title: 'Comprehensive Form',
          description:
              '2-column form with gap slots, gap rows, separators, cross-row alignment',
          screen: ComprehensiveFormDemo(),
        ),
        DemoTile(
          title: 'Dynamic Resize Demo',
          description: 'Resize window to see layout adapt',
          screen: DynamicResizeDemo(),
        ),
        DemoTile(
          title: 'Fluent Builder API',
          description: 'Using AclBuilder',
          screen: FluentApiDemo(),
        ),
        DemoTile(
          title: 'Group Visibility Control',
          description: 'Toggle groups via switches and input-driven callbacks',
          screen: GroupVisibilityDemo(),
        ),
        DemoTile(
          title: 'Responsive Variants',
          description: 'Different layouts at different container widths',
          screen: ResponsiveVariantsDemo(),
        ),
        DemoTile(
          title: 'Row Breakpoints',
          description: 'Rows split into multiple rows at narrow widths',
          screen: RowBreakpointsDemo(),
        ),
        DemoTile(
          title: 'Breakpoint Expansion',
          description:
              '4 expanding items: 1 row → 2 rows → 4 rows as width shrinks',
          screen: BreakpointExpansionDemo(),
        ),
        DemoTile(
          title: 'Inline Component Variants',
          description:
              'Different components shown within the same row at different widths',
          screen: InlineVariantsDemo(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widget Demos Tab
// ---------------------------------------------------------------------------

/// Tab showing individual widget demos organized by category.
class WidgetDemosTab extends StatelessWidget {
  const WidgetDemosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCategoryHeader(context, 'Input & Actions', Icons.touch_app),
        const DemoTile(
          title: 'Buttons',
          description: 'ElevatedButton, TextButton, IconButton, FAB, and more',
          screen: ButtonsDemo(),
        ),
        const DemoTile(
          title: 'Text Inputs',
          description: 'TextField, SearchBar, Autocomplete, DatePickers, and more',
          screen: InputsDemo(),
        ),
        const DemoTile(
          title: 'Selection Controls',
          description: 'Dropdowns, Popup Menus, Menu Anchors, Segmented Controls',
          screen: SelectionDemo(),
        ),
        const DemoTile(
          title: 'Toggles & Options',
          description: 'Checkbox, Switch, Radio, ToggleButtons, ExpansionTile',
          screen: ToggleDemo(),
        ),
        const DemoTile(
          title: 'Sliders & Ranges',
          description: 'Slider, RangeSlider, CupertinoSlider, Stepper',
          screen: SliderDemo(),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Layout & Structure', Icons.dashboard),
        const DemoTile(
          title: 'Cards & Panels',
          description: 'Card, ExpansionPanel, ListTile variants, Material surfaces',
          screen: CardPanelDemo(),
        ),
        const DemoTile(
          title: 'Layout Widgets',
          description: 'Row, Column, Stack, Wrap, Flow, Flex, Table',
          screen: LayoutContainersDemo(),
        ),
        const DemoTile(
          title: 'Scrollable Containers',
          description: 'ListView, GridView, SingleChildScrollView, PageView',
          screen: ScrollableContainersDemo(),
        ),
        const DemoTile(
          title: 'Dialogs & Overlays',
          description: 'AlertDialog, BottomSheet, SnackBar, Tooltip, Banner',
          screen: DialogModalGalleryDemo(),
        ),
        const DemoTile(
          title: 'Tables & Data',
          description: 'DataTable, PaginatedDataTable, sorting and selection',
          screen: DataTablesDemo(),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Display & Info', Icons.info),
        const DemoTile(
          title: 'Labels & Text',
          description: 'Text, RichText, SelectableText, Badge, Chip',
          screen: LabelsDemo(),
        ),
        const DemoTile(
          title: 'Images & Media',
          description: 'Image, Icon, CircleAvatar, FadeInImage, decorations',
          screen: ImagesDemo(),
        ),
        const DemoTile(
          title: 'Navigation',
          description: 'AppBar, TabBar, BottomNavigationBar, Drawer, NavigationRail',
          screen: NavigationDemo(),
        ),
        const DemoTile(
          title: 'Progress Indicators',
          description: 'CircularProgressIndicator, LinearProgressIndicator, RefreshIndicator',
          screen: ProgressDemo(),
        ),
        const DemoTile(
          title: 'Lists & Items',
          description: 'ListTile, CheckboxListTile, SwitchListTile, Dismissible',
          screen: ListsDemo(),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Advanced', Icons.auto_awesome),
        const DemoTile(
          title: 'Trees & Hierarchies',
          description: 'TreeView, expandable tree nodes, drag-and-drop trees',
          screen: TreesDemo(),
        ),
        const DemoTile(
          title: 'Slivers',
          description: 'SliverAppBar, SliverList, SliverGrid, SliverPersistentHeader',
          screen: SliversDemo(),
        ),
        const DemoTile(
          title: 'Animated Widgets',
          description: 'AnimatedContainer, AnimatedOpacity, Hero, AnimatedSwitcher',
          screen: AnimatedDemo(),
        ),
        const DemoTile(
          title: 'Visual Effects',
          description: 'BackdropFilter, ShaderMask, ColorFiltered, ClipPath',
          screen: EffectsDemo(),
        ),
        const DemoTile(
          title: 'Interactions',
          description: 'GestureDetector, Draggable, InkWell, MouseRegion',
          screen: InteractionsDemo(),
        ),
        const DemoTile(
          title: 'Resource Resolution',
          description: 'How widgets resolve labels, icons, tooltips from resources',
          screen: ResourceResolutionDemo(),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roadmap Tab
// ---------------------------------------------------------------------------

/// Tab showing development roadmap and future plans.
class RoadmapTab extends StatelessWidget {
  const RoadmapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRoadmapSection(
          context,
          title: 'Phase 1: Core Infrastructure',
          status: 'Completed',
          statusColor: Colors.green,
          items: [
            'ACL (Advanced Container Layout) system',
            'Basic widget library structure',
            'Theme integration',
          ],
        ),
        _buildRoadmapSection(
          context,
          title: 'Phase 2: Widget Demos',
          status: 'Completed',
          statusColor: Colors.green,
          items: [
            'Button variants and states',
            'Input components with validation',
            'Selection and toggle controls',
            'Layout composition patterns',
            'Navigation widgets',
            'Animation showcases',
            'All 20 demo categories implemented',
          ],
        ),
        _buildRoadmapSection(
          context,
          title: 'Phase 3: Advanced Features',
          status: 'Planned',
          statusColor: Colors.blue,
          items: [
            'Form validation framework',
            'Table with sorting and filtering',
            'Tree view with lazy loading',
            'Rich text editing',
            'Chart and data visualization',
          ],
        ),
        _buildRoadmapSection(
          context,
          title: 'Phase 4: Platform Integration',
          status: 'Future',
          statusColor: Colors.grey,
          items: [
            'Platform-adaptive widgets',
            'Accessibility improvements',
            'Internationalization support',
            'Performance optimizations',
          ],
        ),
      ],
    );
  }

  Widget _buildRoadmapSection(
    BuildContext context, {
    required String title,
    required String status,
    required Color statusColor,
    required List<String> items,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      status == 'Completed'
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: status == 'Completed' ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
