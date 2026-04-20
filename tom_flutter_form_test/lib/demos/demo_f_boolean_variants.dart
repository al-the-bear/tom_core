import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';

// ---------------------------------------------------------------------------
// Demo F — Boolean Variants (Phase 2 scaffold)
// ---------------------------------------------------------------------------

/// Scaffold for the spec's Phase 2 boolean-variants demo:
///
///   * Three concrete boolean implementations (Checkbox / Switch / Toggle)
///     rendered side-by-side — each with its own [TomBool], and another set
///     sharing a single bound [TomBool] so flipping any of the three flips
///     all three.
///   * A "settings" layout that mixes booleans with string inputs and a
///     dropdown, proving `TomFieldDecorationMixin` gives every field the
///     same label / error / description anatomy.
///
/// The concrete boolean widgets ship in Phase 2. Until then the scaffold
/// uses Material `Checkbox`/`Switch`/`SegmentedButton<bool>` wired directly
/// to the same [TomBool] observables, so the "shared-state" behaviour — the
/// single point the demo actually proves visually — is exercisable today.
class DemoFBooleanVariants extends StatefulWidget {
  const DemoFBooleanVariants({super.key});

  @override
  State<DemoFBooleanVariants> createState() => _DemoFBooleanVariantsState();
}

class _DemoFBooleanVariantsState extends State<DemoFBooleanVariants> {
  // Independent booleans — one per variant.
  final _checkboxFlag = TomBool(false);
  final _switchFlag = TomBool(false);
  final _toggleFlag = TomBool(false);

  // Shared boolean — proves the three variants agree on the same value.
  final _shared = TomBool(false);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo F — Boolean Variants',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _buildFormColumn(context);
          final info = _buildInfoColumn(context);
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(child: form),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(child: info),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 16), info],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'Independent (one TomBool per variant)',
          children: [
            _checkboxRow(_checkboxFlag, 'TomFormBoolCheckbox (checkboxFlag)'),
            _switchRow(_switchFlag, 'TomFormBoolSwitch (switchFlag)'),
            _toggleRow(_toggleFlag, 'TomFormBoolToggle (toggleFlag)'),
          ],
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'Shared TomBool — flip any, flip all',
          children: [
            _checkboxRow(_shared, 'Checkbox ↔ shared'),
            _switchRow(_shared, 'Switch ↔ shared'),
            _toggleRow(_shared, 'Toggle ↔ shared'),
          ],
        ),
      ],
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo covers', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            const _Bullet(
                'Three boolean renderings side-by-side — each tied to its '
                'own TomBool so they can diverge.'),
            const _Bullet('A second row where all three share a single '
                'TomBool — toggling any one flips the other two via the '
                'observable channel, no setState required.'),
            const _Bullet('Phase 2 will replace the Material placeholders '
                'with TomFormBoolCheckbox / TomFormBoolSwitch / '
                'TomFormBoolToggle; the bindings are already in place.'),
          ],
        ),
      ),
    );
  }

  Widget _variantCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _checkboxRow(TomBool flag, String label) =>
      TomMultiObservableBuilder(
        observables: [flag],
        builder: (context) => CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: flag.get(),
          onChanged: (v) => flag | (v ?? false),
        ),
      );

  Widget _switchRow(TomBool flag, String label) =>
      TomMultiObservableBuilder(
        observables: [flag],
        builder: (context) => SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: flag.get(),
          onChanged: (v) => flag | v,
        ),
      );

  Widget _toggleRow(TomBool flag, String label) =>
      TomMultiObservableBuilder(
        observables: [flag],
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('off')),
                  ButtonSegment(value: true, label: Text('on')),
                ],
                selected: {flag.get()},
                onSelectionChanged: (s) => flag | s.first,
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      );

  Widget _buildInfoColumn(BuildContext context) {
    return InfoPanel(
      title: 'Bound values',
      children: [
        TomMultiObservableBuilder(
          observables: [_checkboxFlag, _switchFlag, _toggleFlag, _shared],
          builder: (context) {
            final rows = [
              ('checkboxFlag', _checkboxFlag.get()),
              ('switchFlag', _switchFlag.get()),
              ('toggleFlag', _toggleFlag.get()),
              ('shared', _shared.get()),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (name, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$value',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('• $text'),
    );
  }
}
