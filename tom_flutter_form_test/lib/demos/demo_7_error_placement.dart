import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo 7: Error Placement Options
// ---------------------------------------------------------------------------

/// Reference demo for [TomErrorPlacement]. Change the mode live with the
/// segmented control. Use the "trigger errors" buttons below the form to
/// populate the fields with invalid values so the chosen placement is
/// visible without hand-editing.
///
/// Modes:
///   • [TomErrorPlacement.below]       — red caption below the input (default).
///   • [TomErrorPlacement.above]       — red caption above the input.
///   • [TomErrorPlacement.both]        — caption above *and* below.
///   • [TomErrorPlacement.replaceDescription] — error text takes the description
///     (helper-text) slot below the field. If no description is set, the
///     error still appears — the slot materialises for the error. No
///     separate error caption is rendered.
class Demo7ErrorPlacement extends StatefulWidget {
  const Demo7ErrorPlacement({super.key});

  @override
  State<Demo7ErrorPlacement> createState() => _Demo7ErrorPlacementState();
}

class _Demo7ErrorPlacementState extends State<Demo7ErrorPlacement> {
  late final CompanyBasicInfoForm _form;

  TomErrorPlacement _errorPlacement = TomErrorPlacement.below;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope(
      'companyBasicInfo',
      () => CompanyBasicInfoForm(),
    );
    _form.bind(demoState.companyProfile);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  TomFormStyle get _style => TomFormStyle.material3.copyWith(
    defaults: TomFormStyle.material3.defaults.copyWith(
      errorPlacement: _errorPlacement,
    ),
  );

  void _triggerErrors() {
    // Empty name → required error.
    _form.name.setValue('');
    // Lowercase tax id → pattern error (error.format / taxIdFormat).
    _form.taxId.setValue('abc-bad');
    // Non-URL → invalidUrl error.
    _form.website.setValue('not-a-url');
  }

  void _clearErrors() {
    _form.name.setValue('Acme Corporation');
    _form.taxId.setValue('US-12345-ABC');
    _form.website.setValue('https://acme.example.com');
  }

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(id: 'basicForm', elementProvider: _form)
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.taxId.widget)
        .newRow()
        .append((p) => p.website.widget)
        .build(context);

    return DemoScaffold(
      title: 'Demo 7: Error Placement',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReferenceCard(context),
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 16),
            TomFormStyleScope(style: _style, child: formLayout),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _triggerErrors,
                  icon: const Icon(Icons.error_outline),
                  label: const Text('Trigger errors'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _clearErrors,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Clear errors'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error placement reference',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const DemoBullet(
              'below (default) — error caption renders under the input; the row grows downward.',
            ),
            const DemoBullet(
              'above — error caption renders above the input, between the label and the field.',
            ),
            const DemoBullet(
              'both — caption is mirrored above and below. Useful when users may not see one side.',
            ),
            const DemoBullet(
              'replaceDescription — error text takes over the description (helper-text) slot '
              'below the field. If no description was set, the slot materialises for the error. '
              'Compact layouts benefit: no extra error row, but the error stays visible while '
              'typing (unlike the placeholder).',
            ),
            const SizedBox(height: 8),
            Text(
              'Message resolution',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Error text is resolved in three steps — whichever matches first wins:',
            ),
            const SizedBox(height: 4),
            const DemoBullet(
              '1. basePath.errorKey         e.g. companyBasicInfo.name.error.required',
            ),
            const DemoBullet(
              '2. formScope.errorKey        e.g. companyBasicInfo.error.required',
            ),
            const DemoBullet(
              '3. errorKey (global)         e.g. error.required',
            ),
            const SizedBox(height: 4),
            const Text(
              'In real apps the field-scoped message ("Tax ID is required") is preferred '
              'because it names the field; the form/global levels are fallbacks.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TomErrorPlacement',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<TomErrorPlacement>(
              segments: const [
                ButtonSegment(
                  value: TomErrorPlacement.below,
                  label: Text('below'),
                ),
                ButtonSegment(
                  value: TomErrorPlacement.above,
                  label: Text('above'),
                ),
                ButtonSegment(
                  value: TomErrorPlacement.both,
                  label: Text('both'),
                ),
                ButtonSegment(
                  value: TomErrorPlacement.replaceDescription,
                  label: Text('replaceDescription'),
                ),
              ],
              selected: {_errorPlacement},
              onSelectionChanged: (s) =>
                  setState(() => _errorPlacement = s.first),
            ),
          ],
        ),
      ),
    );
  }
}
