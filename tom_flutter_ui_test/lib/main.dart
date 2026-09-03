/// Tom Flutter UI Test Application
///
/// A comprehensive demo app showcasing all tom_flutter_ui widgets and features.
/// The app is organized into multiple tabs:
/// - ACL Demos: Advanced Container Layout system demos
/// - Widget Demos: Individual widget showcases (20+ categories)
/// - Forms/Actions: Form framework demos
/// - Authorization/Resources: Widget authorization and resource demos
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'acl_demos/acl_demos.dart';
import 'common/demo_scaffold.dart';
import 'demo_resources.dart';
import 'forms_demos/forms_demos.dart';
import 'forms_demos/phase2_demos.dart';
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
import 'widget_demos/demo_22_extension_widgets.dart';
import 'widget_demos/demo_23_builders_clips.dart';
import 'widget_demos/demo_24_containers_layout.dart';
import 'widget_demos/demo_25_remaining_widgets.dart';
import 'widget_demos/demo_26_scope_action.dart';
import 'widget_demos/demo_27_forms.dart';
import 'widget_demos/demo_28_authorization.dart';

/// Global locale settings service instance.
///
/// Why: a single app-wide instance is shared by three collaborators that
/// have no common widget ancestor to thread it through — `main()` (bootstrap
/// load), `_TomFlutterUiTestAppState` (listens to rebuild `MaterialApp` on
/// locale change) and the `LanguageSelectorButton` in the `AppBar` (writes
/// the selection). A top-level final keeps that one source of truth without
/// an InheritedWidget layer this demo app doesn't otherwise need.
final localeSettingsService = LocaleSettingsService();

void main() async {
  // Why: ensureInitialized() must run before any plugin/binding call
  // (the SharedPreferences read in localeSettingsService.initialize()
  // touches a platform channel) and before runApp — async work in main()
  // requires a live binding.
  WidgetsFlutterBinding.ensureInitialized();

  // Why: install the Tom UI resource/icon/color adapters before the first
  // frame. Every demo widget resolves its labels, icons and colors by
  // tomId through these global adapters at build time, so they must be set
  // before runApp or the initial build resolves against empty providers.
  initializeDemoResources();

  // Why: await the persisted locale before runApp so the very first frame
  // renders in the user's saved language — initializing after runApp would
  // flash the default locale, then rebuild.
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
    // Why: `length`, the tab bar and the views are all derived from this one
    // descriptor list so they can't drift out of sync — a hardcoded
    // `length: 4` against separately-authored 4-entry `tabs`/`children` lists
    // silently breaks if a demo tab is added to one list but not the others
    // (code_quality §30b).
    return DefaultTabController(
      length: _mainTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tom Flutter UI'),
          actions: [
            LanguageSelectorButton(localeService: localeSettingsService),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final tab in _mainTabs)
                Tab(icon: Icon(tab.icon), text: tab.label),
            ],
          ),
        ),
        body: TabBarView(children: [for (final tab in _mainTabs) tab.view]),
      ),
    );
  }
}

/// The single source of truth for the top-level tab structure: each entry
/// pairs a tab's icon + label with the view shown under it, so the
/// `DefaultTabController` length, the `TabBar.tabs` and the `TabBarView.children`
/// are all derived from one list and cannot fall out of sync (code_quality §30b).
const List<({IconData icon, String label, Widget view})> _mainTabs = [
  (icon: Icons.grid_view, label: 'ACL Demos', view: AclDemosTab()),
  (icon: Icons.widgets, label: 'Widget Demos', view: WidgetDemosTab()),
  (icon: Icons.dynamic_form, label: 'Forms/Actions', view: FormsActionsTab()),
  (
    icon: Icons.security,
    label: 'Authorization/Resources',
    view: AuthorizationResourcesTab(),
  ),
];

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
        TomScope.withScope(
          'demo01',
          () => DemoTile(
            title: 'Buttons',
            description:
                'ElevatedButton, TextButton, IconButton, FAB, and more',
            screen: ButtonsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo02',
          () => DemoTile(
            title: 'Text Inputs',
            description:
                'TextField, SearchBar, Autocomplete, DatePickers, and more',
            screen: InputsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo03',
          () => DemoTile(
            title: 'Selection Controls',
            description:
                'Dropdowns, Popup Menus, Menu Anchors, Segmented Controls',
            screen: SelectionDemo(),
          ),
        ),
        TomScope.withScope(
          'demo04',
          () => DemoTile(
            title: 'Toggles & Options',
            description:
                'Checkbox, Switch, Radio, ToggleButtons, ExpansionTile',
            screen: ToggleDemo(),
          ),
        ),
        TomScope.withScope(
          'demo05',
          () => DemoTile(
            title: 'Sliders & Ranges',
            description: 'Slider, RangeSlider, CupertinoSlider, Stepper',
            screen: SliderDemo(),
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Layout & Structure', Icons.dashboard),
        TomScope.withScope(
          'demo06',
          () => DemoTile(
            title: 'Cards & Panels',
            description:
                'Card, ExpansionPanel, ListTile variants, Material surfaces',
            screen: CardPanelDemo(),
          ),
        ),
        TomScope.withScope(
          'demo07',
          () => DemoTile(
            title: 'Layout Widgets',
            description: 'Row, Column, Stack, Wrap, Flow, Flex, Table',
            screen: LayoutContainersDemo(),
          ),
        ),
        TomScope.withScope(
          'demo08',
          () => DemoTile(
            title: 'Scrollable Containers',
            description: 'ListView, GridView, SingleChildScrollView, PageView',
            screen: ScrollableContainersDemo(),
          ),
        ),
        TomScope.withScope(
          'demo09',
          () => DemoTile(
            title: 'Dialogs & Overlays',
            description: 'AlertDialog, BottomSheet, SnackBar, Tooltip, Banner',
            screen: DialogModalGalleryDemo(),
          ),
        ),
        TomScope.withScope(
          'demo10',
          () => DemoTile(
            title: 'Tables & Data',
            description: 'DataTable, PaginatedDataTable, sorting and selection',
            screen: DataTablesDemo(),
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Display & Info', Icons.info),
        TomScope.withScope(
          'demo11',
          () => DemoTile(
            title: 'Labels & Text',
            description: 'Text, RichText, SelectableText, Badge, Chip',
            screen: LabelsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo12',
          () => DemoTile(
            title: 'Images & Media',
            description: 'Image, Icon, CircleAvatar, FadeInImage, decorations',
            screen: ImagesDemo(),
          ),
        ),
        TomScope.withScope(
          'demo13',
          () => DemoTile(
            title: 'Navigation',
            description:
                'AppBar, TabBar, BottomNavigationBar, Drawer, NavigationRail',
            screen: NavigationDemo(),
          ),
        ),
        TomScope.withScope(
          'demo14',
          () => DemoTile(
            title: 'Progress Indicators',
            description:
                'CircularProgressIndicator, LinearProgressIndicator, RefreshIndicator',
            screen: ProgressDemo(),
          ),
        ),
        TomScope.withScope(
          'demo15',
          () => DemoTile(
            title: 'Lists & Items',
            description:
                'ListTile, CheckboxListTile, SwitchListTile, Dismissible',
            screen: ListsDemo(),
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(context, 'Advanced', Icons.auto_awesome),
        TomScope.withScope(
          'demo16',
          () => DemoTile(
            title: 'Trees & Hierarchies',
            description: 'TreeView, expandable tree nodes, drag-and-drop trees',
            screen: TreesDemo(),
          ),
        ),
        TomScope.withScope(
          'demo17',
          () => DemoTile(
            title: 'Slivers',
            description:
                'SliverAppBar, SliverList, SliverGrid, SliverPersistentHeader',
            screen: SliversDemo(),
          ),
        ),
        TomScope.withScope(
          'demo18',
          () => DemoTile(
            title: 'Animated Widgets',
            description:
                'AnimatedContainer, AnimatedOpacity, Hero, AnimatedSwitcher',
            screen: AnimatedDemo(),
          ),
        ),
        TomScope.withScope(
          'demo19',
          () => DemoTile(
            title: 'Visual Effects',
            description: 'BackdropFilter, ShaderMask, ColorFiltered, ClipPath',
            screen: EffectsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo20',
          () => DemoTile(
            title: 'Interactions',
            description: 'GestureDetector, Draggable, InkWell, MouseRegion',
            screen: InteractionsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo21',
          () => DemoTile(
            title: 'Resource Resolution',
            description:
                'How widgets resolve labels, icons, tooltips from resources',
            screen: ResourceResolutionDemo(),
          ),
        ),
        TomScope.withScope(
          'demo22',
          () => DemoTile(
            title: 'Extension Widgets',
            description:
                'AppBar, NavigationDestination, TableCell, CupertinoTabView, RefreshProgressIndicator',
            screen: ExtensionWidgetsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo23',
          () => DemoTile(
            title: 'Builders, Clips & Base',
            description:
                'FutureBuilder, StreamBuilder, LayoutBuilder, Clips, Opacity, RawChip, EditableText',
            screen: BuildersClipsDemo(),
          ),
        ),
        TomScope.withScope(
          'demo24',
          () => DemoTile(
            title: 'Containers & Layout',
            description:
                'Scaffold, DecoratedBox, Transform, Flow, CustomPaint, GridTile, Slivers',
            screen: ContainersLayoutDemo(),
          ),
        ),
        TomScope.withScope(
          'demo25',
          () => DemoTile(
            title: 'Remaining Widgets',
            description: 'Dialogs, Buttons, Navigation, Labels, Lists, Images',
            screen: RemainingWidgetsDemo(),
          ),
        ),
        const SizedBox(height: 16),
        _buildCategoryHeader(
          context,
          'Scope & Architecture',
          Icons.account_tree,
        ),
        TomScope.withScope(
          'demo26',
          () => DemoTile(
            title: 'Scope & Action',
            description:
                'TomScreenElementsProviderBase, nested scopes, reusable widget trees',
            screen: ScopeActionDemo(),
          ),
        ),
        TomScope.withScope(
          'demo27',
          () => DemoTile(
            title: 'Forms',
            description:
                'Form fields in scoped providers, validation, ACL form layout',
            screen: FormsDemo(),
          ),
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
// Forms/Actions Tab
// ---------------------------------------------------------------------------

/// Tab showing form framework demos.
class FormsActionsTab extends StatelessWidget {
  const FormsActionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        DemoTile(
          title: 'Forms Overview',
          description:
              'TomForm field types: email, password, text, int, double — with validation',
          screen: FormsOverviewDemo(),
        ),
        DemoTile(
          title: 'Demo E — Selection Variants',
          description:
              'Segmented / RadioGroup / ChoiceChips / FilterChips / MultiCheckbox '
              'against a shared TomSelectableSource<String>',
          screen: SelectionVariantsDemo(),
        ),
        DemoTile(
          title: 'Demo F — Boolean Variants',
          description:
              'Checkbox / Switch / Toggle independently, in lock-step, and in a '
              'mixed settings layout',
          screen: BooleanVariantsDemo(),
        ),
        DemoTile(
          title: 'Demo G — Complex Breakpoints',
          description:
              'TomFormStyleScope with styleBpOverrides, nested theme-only scope, '
              'two-column → one-column collapse',
          screen: ComplexBreakpointsDemo(),
        ),
        DemoTile(
          title: 'Demo H — Complex Authorization',
          description:
              'Action-icon auth gating, UIStateController cross-field deps, '
              'group modes, subform auth ceiling',
          screen: ComplexAuthDemo(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Authorization/Resources Tab
// ---------------------------------------------------------------------------

/// Tab showing authorization and resource resolution demos.
class AuthorizationResourcesTab extends StatelessWidget {
  const AuthorizationResourcesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TomScope.withScope(
          'demo21',
          () => DemoTile(
            title: 'Resource Resolution',
            description:
                'How widgets resolve labels, icons, tooltips from resources',
            screen: ResourceResolutionDemo(),
          ),
        ),
        TomScope.withScope(
          'demo28',
          () => DemoTile(
            title: 'Authorization',
            description:
                'Widget visibility, readonly state, group authorization, TomAuthorizationGroup',
            screen: AuthorizationDemo(),
          ),
        ),
      ],
    );
  }
}
