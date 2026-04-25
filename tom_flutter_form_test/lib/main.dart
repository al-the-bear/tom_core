import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'main.reflection.dart';
import 'state/application_state.dart';
import 'demos/demo_1_basic_form.dart';
import 'demos/demo_2_nested_forms.dart';
import 'demos/demo_3_authorization.dart';
import 'demos/demo_4_validation.dart';
import 'demos/demo_5_settings.dart';
import 'demos/demo_6_field_layout.dart';
import 'demos/demo_7_error_placement.dart';
import 'demos/demo_8_breakpoints.dart';
import 'demos/demo_9_preset_showcase.dart';
import 'demos/demo_10_central_json_style.dart';
import 'demos/demo_a_lifecycle.dart';
import 'demos/demo_b_authorization.dart';
import 'demos/demo_c_nested_theming.dart';
import 'demos/demo_d_hide_unauthorized.dart';
import 'demos/demo_e_selection_variants.dart';
import 'demos/demo_f_boolean_variants.dart';
import 'demos/demo_g_breakpoint_scenarios.dart';
import 'demos/demo_h_complex_authorization.dart';
import 'demos/demo_h_a_master_detail.dart';
import 'demos/demo_h_b_expandable_rows.dart';
import 'demos/demo_h_c_editable_table.dart';
import 'demos/demo_h_d_customer_form.dart';
import 'demos/demo_h_e_customer_form_ro.dart';
import 'demos/demo_i_numeric_forms.dart';
import 'demos/demo_j_date_time_forms.dart';
import 'demos/demo_k_enum_object.dart';
import 'demos/demo_l_file_nullable.dart';
import 'demos/demo_m_cupertino_basics.dart';
import 'demos/demo_n_cupertino_numeric_datetime.dart';
import 'demos/demo_o_cupertino_search_lookup_file.dart';
import 'demos/demo_p_family_swap_breakpoint.dart';
import 'demos/demo_q_auth_empty_overlay.dart';
import 'demos/demo_r_tree_radio_infinite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeReflection();

  // Load resources from JSON asset and register with the resource provider.
  final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
  final resources = json.decode(jsonStr) as Map<String, dynamic>;
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(resources),
  );

  // Touch demoState so it is initialised (and pre-populated) before the UI
  // starts — avoids any first-frame jank from lazy field initialisation.
  demoState;

  runApp(const FormDemoApp());
}

class FormDemoApp extends StatelessWidget {
  const FormDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Form Framework Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoListScreen(),
    );
  }
}

class DemoListScreen extends StatelessWidget {
  const DemoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Framework Demos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DemoHeader(
            title: 'Tom Form Framework',
            description: 'Comprehensive demo showcasing form binding, '
                'validation, authorization, and ACL layout.',
          ),
          const SizedBox(height: 16),
          _DemoSectionHeader(label: 'Phase 1 \u2014 Spec-aligned demos'),
          _DemoTile(
            icon: Icons.play_circle_outline,
            title: 'Demo A: Lifecycle & Validation',
            description: 'bind/save/discard, sync/async/cross-field '
                'validation, pristine behaviour, error banner, form actions.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoALifecycle()),
            ),
          ),
          _DemoTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Demo B: Authorization & Events',
            description: '4 auth states, groups + modes, authorizer, '
                'UI-state controller, live event log with '
                'FieldAuthChangedEvent.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoBAuthorization()),
            ),
          ),
          _DemoTile(
            icon: Icons.layers_outlined,
            title: 'Demo C: Nested Forms & Theming',
            description: 'Nested CustomerForm + billing/shipping, dirty '
                'tracking, live TomFormStyle switching, per-section '
                'styling, styleBpOverrides, Classic + new coexistence.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoCNestedTheming()),
            ),
          ),
          _DemoTile(
            icon: Icons.visibility_off_outlined,
            title: 'Demo D: Hide on Authorization',
            description: 'setAclDefaultHideUnauthorized + read / disabled '
                'states on a form (row elision) and a gallery of ten '
                'non-form Tom widgets.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoDHideUnauthorized()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(label: 'Phase 2 \u2014 Extended field flavours'),
          _DemoTile(
            icon: Icons.check_box_outlined,
            title: 'Demo E: Selection Variants',
            description: 'Five single- and multi-select flavours '
                '(FilterChips / MultiCheckbox / Segmented / RadioGroup / '
                'ChoiceChips) against one shared source. Scaffolded today; '
                'widgets land in Phase 2.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoESelectionVariants()),
            ),
          ),
          _DemoTile(
            icon: Icons.toggle_on_outlined,
            title: 'Demo F: Boolean Variants',
            description: 'Three boolean renderings (Checkbox / Switch / '
                'Toggle) side-by-side, independent and shared-state rows.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoFBooleanVariants()),
            ),
          ),
          _DemoTile(
            icon: Icons.aspect_ratio,
            title: 'Demo G: Complex Breakpoint Scenarios',
            description: 'ProjectBriefForm across four style + theme '
                'presets at 400 / 800 / 1200 / 1600 px, with every ACL '
                'breakpoint API active + priority widget-type swap.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoGBreakpointScenarios()),
            ),
          ),
          _DemoTile(
            icon: Icons.lock_outlined,
            title: 'Demo H: Complex Authorization Scenarios',
            description: 'Same ProjectBriefForm as Demo G, overlaid with '
                'per-field / per-section / form-level auth switches so '
                'the re-layout is verifiable under live auth changes.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoHComplexAuthorization()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 2a \u2014 Collections & master-detail'),
          _DemoTile(
            icon: Icons.view_sidebar_outlined,
            title: 'Demo H-A: Master-Detail Customer Editor',
            description: 'TomMasterDetailListForm with TomListForm + the '
                'row sub-form rendered directly in the detail pane (no '
                'sibling form). Selection guarded by the built-in '
                'unsaved-changes prompt. Drag-handle reorder + toolbar '
                'add/remove. Interleaved list+detail event log.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoHAMasterDetail()),
            ),
          ),
          _DemoTile(
            icon: Icons.unfold_more,
            title: 'Demo H-B: Expandable Rows (Order Items)',
            description: 'TomListForm rendered as ExpansionTile per row; '
                'parent OrderForm.isDirty / .isValid aggregate over '
                'expanded + collapsed children alike.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoHBExpandableRows()),
            ),
          ),
          _DemoTile(
            icon: Icons.table_rows_outlined,
            title: 'Demo H-C: Editable Order-Items Table',
            description: 'DataTable with editable field widgets in cells, '
                'computed-total column + form-level total, drag-handle '
                'reorder, TomErrorView for cross-field "min items" rule.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoHCEditableTable()),
            ),
          ),
          _DemoTile(
            icon: Icons.person_outline,
            title: 'Demo H-D: Customer Form (master-detail)',
            description: 'Full customer record: contact info + billing '
                'address (flat fields) + two TomMasterDetailListForms '
                'for shipping addresses and orders, with toolbar '
                'add/remove and drag-handle reorder in each master pane. '
                'Each order owns an inline reorderable items table.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoHDCustomerForm()),
            ),
          ),
          _DemoTile(
            icon: Icons.receipt_long_outlined,
            title: 'Demo H-E: Customer Form (read-only + edit dialogs)',
            description: 'Same customer data as H-D. Shipping addresses and '
                'orders shown as compact read-only rows. Each row has an '
                '"Edit" button that opens a full edit dialog. "Add" '
                'creates a new item and opens its dialog immediately.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoHECustomerForm()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 3 — Numeric, date/time & duration fields'),
          _DemoTile(
            icon: Icons.calculate_outlined,
            title: 'Demo I: Numeric Forms',
            description: 'IntInput / IntSlider / IntStepper, '
                'CurrencyDoubleInput with locale switcher, percent input, '
                'double slider, and Int/Double range sliders.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoINumericForms()),
            ),
          ),
          _DemoTile(
            icon: Icons.event_note_outlined,
            title: 'Demo J: Date/Time/Duration Forms',
            description: 'DatePicker, inline DateCalendar, TimePicker, '
                'DateTimePicker, DateRangePicker, and DurationInput vs. '
                'an equivalent IntSlider in minutes (two-way sync).',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoJDateTimeForms()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 4 \u2014 Enum, object, file & nullable fields'),
          _DemoTile(
            icon: Icons.format_list_bulleted_outlined,
            title: 'Demo K: Enum, Object & Lookup',
            description: 'Enum dropdown / segmented / radio / chips, '
                'object dropdown + chips (Country), search field over a '
                '~5 000-item source, and a modal lookup dialog.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoKEnumObject()),
            ),
          ),
          _DemoTile(
            icon: Icons.upload_file_outlined,
            title: 'Demo L: Files & Nullable Variants',
            description: 'FileUpload + FileDropzone side-by-side with a '
                'shared in-memory picker, plus a nullable subform '
                '(string / int / double / date) distinguishing pristine '
                'vs. set vs. explicitly-null states.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoLFileNullable()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 5a — Cupertino string + bool + selection'),
          _DemoTile(
            icon: Icons.phone_iphone,
            title: 'Demo M: Material vs Cupertino (Phase 5a)',
            description: 'Side-by-side panels — Material concretes on the '
                'left, Cupertino concretes on the right — bound to one '
                'shared state. A radio toggle swaps the page-root '
                'TomFormStyleScope.style between material3 and Cupertino '
                'so the entire anatomy reflows live.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DemoMCupertinoBasics()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 5b — Cupertino numeric + date/time'),
          _DemoTile(
            icon: Icons.calendar_view_day,
            title: 'Demo N: Cupertino numeric + date/time (Phase 5b)',
            description: 'Nine Phase 5b Cupertino concretes (int/double + '
                'date/time/duration/range pickers) inside a nested '
                'TomFormStyleScope where the inner scope keeps style: null '
                'and only swaps the themeSpec by breakpoint — exercises the '
                'optional-style scope feature.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoNCupertinoNumericDateTime()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 5c — Cupertino search/lookup/file + family swap'),
          _DemoTile(
            icon: Icons.search,
            title: 'Demo O: Cupertino search / lookup / file (Phase 5c)',
            description: 'Six remaining Phase 5c Cupertino concretes — '
                'SearchInput<City>, LookupSheet<Country>, FileUpload, plus '
                'the four nullable variants (NString / NInt / NDouble / '
                'NDate) — pinned to TomCupertinoFormStyle.cupertino.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoOCupertinoSearchLookupFile()),
            ),
          ),
          _DemoTile(
            icon: Icons.compare_arrows,
            title: 'Demo P: FormFieldFamily swap by breakpoint (Phase 5c)',
            description: 'One Phase5cFamilyForm declaration resolves '
                'Material vs Cupertino concretes via FormFieldFamily; '
                'LayoutBuilder + styleBpOverrides flip both family and '
                'style at 700 px while shared state survives the swap.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoPFamilySwapBreakpoint()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(
              label: 'Phase 6 \u2014 Non-form custom widgets (\u00a723)'),
          _DemoTile(
            icon: Icons.shield_outlined,
            title: 'Demo Q: Auth / Empty / Overlay (Phase 6)',
            description: 'TomAuthGuard wraps a profile panel; TomEmptyState '
                'fills an empty items pane; TomLoadingOverlay scrims the '
                'pane during a 600 ms simulated save.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoQAuthEmptyOverlay()),
            ),
          ),
          _DemoTile(
            icon: Icons.account_tree_outlined,
            title: 'Demo R: Tree / Radio / Infinite scroll (Phase 6)',
            description: 'TomAuthTreeView with per-node auth + inheritance; '
                'TomRadioGroup with group-level auth; TomInfiniteScroll over '
                'a 10 000-row source with TomSkeletonLoader + '
                'TomErrorBoundary, including a synthetic page-fetch failure.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoRTreeRadioInfinite()),
            ),
          ),
          const SizedBox(height: 12),
          _DemoSectionHeader(label: 'Supporting reference demos'),
          _DemoTile(
            icon: Icons.edit_document,
            title: 'Demo 1: Basic Form',
            description: 'TomForm binding, StringInput/Dropdown, validators, '
                'slow validation with pending state.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo1BasicForm()),
            ),
          ),
          _DemoTile(
            icon: Icons.account_tree,
            title: 'Demo 2: Nested Forms',
            description: 'Parent form with nested AddressForm and PersonForm, '
                'hierarchical validation.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo2NestedForms()),
            ),
          ),
          _DemoTile(
            icon: Icons.security,
            title: 'Demo 3: Authorization',
            description: 'Per-resource authorization, dynamic auth changes, '
                'read-only and hidden states.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo3Authorization()),
            ),
          ),
          _DemoTile(
            icon: Icons.check_circle_outline,
            title: 'Demo 4: Validation',
            description: 'Fast validators vs slow validators, '
                'validation states, TomFormInspector.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo4Validation()),
            ),
          ),
          _DemoTile(
            icon: Icons.settings,
            title: 'Demo 5: Settings Form',
            description: 'Dropdown fields for selection, compact style, '
                'boolean toggles.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo5SettingsForm()),
            ),
          ),
          _DemoTile(
            icon: Icons.view_agenda_outlined,
            title: 'Demo 6: Field Layout Options',
            description: 'Live-switch labelPlacement, requiredIndicator, and '
                'descriptionPlacement on the same form.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo6FieldLayout()),
            ),
          ),
          _DemoTile(
            icon: Icons.report_gmailerrorred,
            title: 'Demo 7: Error Placement',
            description: 'ErrorPlacement options including replaceDescription; '
                'explains the 3-step error message resolution chain.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo7ErrorPlacement()),
            ),
          ),
          _DemoTile(
            icon: Icons.aspect_ratio,
            title: 'Demo 8: Breakpoints',
            description: 'Draggable splitter drives TomFormStyleScope width; '
                'gaps, error border, and error icon react live via breakpoint '
                'overrides.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo8Breakpoints()),
            ),
          ),
          _DemoTile(
            icon: Icons.grid_view,
            title: 'Demo 9: Preset Showcase',
            description: 'Grid of field types \u00d7 presets (material3, '
                'compact, bordered) with a withTheme() toggle.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo9PresetShowcase()),
            ),
          ),
          _DemoTile(
            icon: Icons.data_object,
            title: 'Demo 10: Central JSON-Driven Style',
            description: 'Single root-level TomFormStyleScope; every style '
                'property plus breakpoint variants defined in '
                'demo_resources.json.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Demo10CentralJsonStyle()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoHeader extends StatelessWidget {
  final String title;
  final String description;

  const _DemoHeader({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoSectionHeader extends StatelessWidget {
  final String label;
  const _DemoSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
