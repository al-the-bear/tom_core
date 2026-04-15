import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 6: Field Layout Options
// ---------------------------------------------------------------------------

/// Reference demo for the per-field layout options on [TomFormStyleLegacy].
///
/// Switch placements live with the segmented controls — all fields share a
/// single form instance, so the same data rebuilds under the chosen style.
///
/// Options covered:
///   • [LabelPlacement]          — above / below / floating / inline / hidden
///   • [RequiredIndicator]       — independent for label and hint
///   • [DescriptionPlacement]    — above / below
class Demo6FieldLayout extends StatefulWidget {
  const Demo6FieldLayout({super.key});

  @override
  State<Demo6FieldLayout> createState() => _Demo6FieldLayoutState();
}

class _Demo6FieldLayoutState extends State<Demo6FieldLayout> {
  late final CompanyBasicInfoForm _form;

  LabelPlacement _labelPlacement = LabelPlacement.above;
  RequiredIndicator _requiredIndicatorOnLabel = RequiredIndicator.asterisk;
  RequiredIndicator _requiredIndicatorOnHint = RequiredIndicator.none;
  DescriptionPlacement _descriptionPlacement = DescriptionPlacement.below;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('companyBasicInfo', () => CompanyBasicInfoForm());
    _form.bind(demoState.companyProfile);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  TomFormStyleLegacy get _style => TomFormStyleLegacy.material3.copyWith(
        labelPlacement: _labelPlacement,
        requiredIndicator: _requiredIndicatorOnLabel,
        requiredIndicatorOnHint: _requiredIndicatorOnHint,
        descriptionPlacement: _descriptionPlacement,
      );

  @override
  Widget build(BuildContext context) {
    final formLayout = TomAclBuilder(
      id: 'basicForm',
      elementProvider: _form,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.industry.widget)
        .addRowBreakpoint(atWidth: 400)
        .append((p) => p.taxId.widget, dist: 16)
        .newRow()
        .append((p) => p.website.widget)
        .build(context);

    return DemoScaffold(
      title: 'Demo 6: Field Layout Options',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReferenceCard(context),
            const SizedBox(height: 16),
            _buildControls(context),
            const SizedBox(height: 16),
            TomFormStyleScopeLegacy(
              style: _style,
              child: formLayout,
            ),
          ],
        ),
      ),
    );
  }

  // ── Reference / tutorial card ────────────────────────────────────────────

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field layout reference',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const _Bullet('LabelPlacement.above — label sits on its own line above the input (default).'),
            const _Bullet('LabelPlacement.below — label sits directly below the input, above any description.'),
            const _Bullet('LabelPlacement.floating — Material floating label inside the input border.'),
            const _Bullet('LabelPlacement.inline — label on the left, input on the right in one row.'),
            const _Bullet('LabelPlacement.hidden — no label; use a hint or leave context to the form title.'),
            const SizedBox(height: 6),
            const _Bullet('RequiredIndicator (label) — red * / " (required)" / none. Controls the label decoration.'),
            const _Bullet('RequiredIndicator (hint) — same options, independent of the label. Set both for label + hint.'),
            const SizedBox(height: 6),
            const _Bullet('DescriptionPlacement.below — helper text under the field (default).'),
            const _Bullet('DescriptionPlacement.above — helper text between label and input (when label is above).'),
          ],
        ),
      ),
    );
  }

  // ── Live controls ────────────────────────────────────────────────────────

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabelRow(label: 'LabelPlacement'),
            SegmentedButton<LabelPlacement>(
              segments: const [
                ButtonSegment(value: LabelPlacement.above, label: Text('above')),
                ButtonSegment(value: LabelPlacement.below, label: Text('below')),
                ButtonSegment(value: LabelPlacement.floating, label: Text('floating')),
                ButtonSegment(value: LabelPlacement.inline, label: Text('inline')),
                ButtonSegment(value: LabelPlacement.hidden, label: Text('hidden')),
              ],
              selected: {_labelPlacement},
              onSelectionChanged: (s) =>
                  setState(() => _labelPlacement = s.first),
            ),
            const SizedBox(height: 12),
            _LabelRow(label: 'RequiredIndicator — label'),
            SegmentedButton<RequiredIndicator>(
              segments: const [
                ButtonSegment(value: RequiredIndicator.asterisk, label: Text('asterisk')),
                ButtonSegment(value: RequiredIndicator.text, label: Text('text')),
                ButtonSegment(value: RequiredIndicator.none, label: Text('none')),
              ],
              selected: {_requiredIndicatorOnLabel},
              onSelectionChanged: (s) =>
                  setState(() => _requiredIndicatorOnLabel = s.first),
            ),
            const SizedBox(height: 12),
            _LabelRow(label: 'RequiredIndicator — hint'),
            SegmentedButton<RequiredIndicator>(
              segments: const [
                ButtonSegment(value: RequiredIndicator.asterisk, label: Text('asterisk')),
                ButtonSegment(value: RequiredIndicator.text, label: Text('text')),
                ButtonSegment(value: RequiredIndicator.none, label: Text('none')),
              ],
              selected: {_requiredIndicatorOnHint},
              onSelectionChanged: (s) =>
                  setState(() => _requiredIndicatorOnHint = s.first),
            ),
            const SizedBox(height: 12),
            _LabelRow(label: 'DescriptionPlacement'),
            SegmentedButton<DescriptionPlacement>(
              segments: const [
                ButtonSegment(value: DescriptionPlacement.above, label: Text('above')),
                ButtonSegment(value: DescriptionPlacement.below, label: Text('below')),
              ],
              selected: {_descriptionPlacement},
              onSelectionChanged: (s) =>
                  setState(() => _descriptionPlacement = s.first),
            ),
          ],
        ),
      ),
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

class _LabelRow extends StatelessWidget {
  final String label;
  const _LabelRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
