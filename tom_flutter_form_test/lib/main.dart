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
            description: 'Outer TomFormStyleScope with three-band '
                'styleBpOverrides plus nested scopes. Drag the splitter '
                'to cross tablet/desktop thresholds.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoGBreakpointScenarios()),
            ),
          ),
          _DemoTile(
            icon: Icons.lock_outlined,
            title: 'Demo H: Complex Authorization Scenarios',
            description: 'Three group modes active at once, a '
                'UIStateController stack, and form-level auth ceiling '
                '\u2014 all visible in the field-state table.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DemoHComplexAuthorization()),
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
