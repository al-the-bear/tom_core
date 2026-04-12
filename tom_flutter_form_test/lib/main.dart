import 'package:flutter/material.dart';

import 'reflection_init.dart';
import 'demos/demo_1_basic_form.dart';
import 'demos/demo_2_nested_forms.dart';
import 'demos/demo_3_authorization.dart';
import 'demos/demo_4_validation.dart';
import 'demos/demo_5_settings.dart';

void main() {
  initializeReflection();
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
