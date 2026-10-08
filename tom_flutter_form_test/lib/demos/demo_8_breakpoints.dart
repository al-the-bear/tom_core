import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo 8: Breakpoints
// ---------------------------------------------------------------------------

/// End-to-end proof of breakpoint resolution.
///
/// Drag the splitter to resize the form's available width. Everything inside
/// the splitter is wrapped in a [TomFormStyleScope] that captures the
/// available width via its built-in `LayoutBuilder`; breakpoint-aware
/// properties on [TomFieldStyle] resolve automatically against that width.
///
/// Live-responsive properties demonstrated (all use `(minWidth, value)`
/// overrides lists — resolution is highest `minWidth <= available`):
///
///   - `labelPlacement`                  (floating < 400, above < 700, inline >= 700)
///   - `labelStyle` / `hintStyle`        (smaller fonts at narrow widths)
///   - `labelFieldGap` & `errorFieldGap` (tighter at narrow widths)
///   - `errorBorderEnabled`              (off < 400px, on >= 400px)
///   - `errorIconEnabled`                (off < 500px, on >= 500px)
///
/// No demo code reads the width directly — the scope publishes it and
/// resolution happens inside `TomFormStyle.resolveFieldStyle`.
class Demo8Breakpoints extends StatefulWidget {
  const Demo8Breakpoints({super.key});

  @override
  State<Demo8Breakpoints> createState() => _Demo8BreakpointsState();
}

class _Demo8BreakpointsState extends State<Demo8Breakpoints> {
  late final CompanyBasicInfoForm _form;

  /// Width fraction of the form pane (0.1 .. 1.0).
  double _widthFraction = 1.0;

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

  /// Breakpoint-aware style. The override lists ride on `TomFieldStyle`;
  /// the scope feeds the live width into `resolveFieldStyle`.
  TomFormStyle get _style => TomFormStyle(
    defaults:
        const TomFieldStyle(
          labelPlacement: TomLabelPlacement.floating,
          labelPlacementBpOverrides: [
            (400, TomLabelPlacement.above),
            (700, TomLabelPlacement.inline),
          ],
          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          labelStyleBpOverrides: [
            (400, TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            (700, TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
          hintStyle: TextStyle(fontSize: 11),
          hintStyleBpOverrides: [
            (400, TextStyle(fontSize: 13)),
            (700, TextStyle(fontSize: 15)),
          ],
          labelFieldGap: 2.0,
          labelFieldGapBpOverrides: [(400, 4.0), (700, 8.0)],
          errorFieldGap: 2.0,
          errorFieldGapBpOverrides: [(400, 4.0), (700, 8.0)],
          errorBorderEnabled: false,
          errorBorderEnabledBpOverrides: [(400, true)],
          errorIconEnabled: false,
          errorIconEnabledBpOverrides: [(500, true)],
        ).copyWith(
          fieldBorder: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFBA1A1A), width: 2),
          ),
        ),
  );

  void _triggerErrors() {
    _form.name.setValue('');
    _form.taxId.setValue('bad value!');
    _form.website.setValue('not-a-url');
  }

  void _clearErrors() {
    _form.name.setValue('Acme Corporation');
    _form.taxId.setValue('US-12345-ABC');
    _form.website.setValue('https://acme.example.com');
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo 8: Breakpoints',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final paneWidth = (totalWidth * _widthFraction).clamp(
            140.0,
            totalWidth,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReferenceCard(context),
                const SizedBox(height: 16),
                _buildSplitter(totalWidth, paneWidth),
                const SizedBox(height: 16),
                _buildActiveBreakpointBadges(context, paneWidth),
                const SizedBox(height: 16),
                // Constrain the form pane to the chosen width. The style
                // scope's LayoutBuilder picks up THIS constraint and
                // publishes it to every descendant field.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: paneWidth,
                    child: TomFormStyleScope(
                      style: _style,
                      child: _buildForm(),
                    ),
                  ),
                ),
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
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return TomAclBuilder(id: 'basicForm', elementProvider: _form)
        .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.name.widget)
        .newRow()
        .append((p) => p.industry.widget)
        .newRow()
        .append((p) => p.taxId.widget)
        .newRow()
        .append((p) => p.website.widget)
        .build(context);
  }

  // ── Splitter ─────────────────────────────────────────────────────────────

  Widget _buildSplitter(double totalWidth, double paneWidth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Form pane width',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text(
                  '${paneWidth.toStringAsFixed(0)} px',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            Slider(
              value: _widthFraction,
              min: 140.0 / totalWidth.clamp(141.0, double.infinity),
              max: 1.0,
              onChanged: (v) => setState(() => _widthFraction = v),
            ),
            Text(
              'Drag to resize. Breakpoint-aware properties below react live.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Active-breakpoint badges ─────────────────────────────────────────────

  Widget _buildActiveBreakpointBadges(BuildContext context, double width) {
    final gap = width >= 700 ? '8px' : (width >= 400 ? '4px' : '2px');
    final border = width >= 400 ? 'on' : 'off';
    final icon = width >= 500 ? 'on' : 'off';
    final label = width >= 700
        ? 'inline'
        : (width >= 400 ? 'above' : 'floating');
    final font = width >= 700 ? '15px' : (width >= 400 ? '13px' : '11px');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: 'labelPlacement', value: label),
            _Badge(label: 'labelStyle', value: font),
            _Badge(label: 'hintStyle', value: font),
            _Badge(label: 'labelFieldGap', value: gap),
            _Badge(label: 'errorFieldGap', value: gap),
            _Badge(label: 'errorBorderEnabled', value: border),
            _Badge(label: 'errorIconEnabled', value: icon),
          ],
        ),
      ),
    );
  }

  // ── Reference card ───────────────────────────────────────────────────────

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breakpoint reference',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const DemoBullet(
              'Breakpointed properties ship as a plain value + a '
              '(minWidth, value) overrides list. Highest matching minWidth '
              'wins; below all breakpoints the plain value applies.',
            ),
            const DemoBullet(
              'TomFormStyleScope wraps its child in a LayoutBuilder and '
              'publishes the max width via widthOf — resolution is automatic.',
            ),
            const DemoBullet(
              'Drag the splitter. Cross 400px: label moves floating → above, '
              'fonts bump up, gaps grow, error border turns on. Cross 500px: '
              'error icon appears. Cross 700px: label moves above → inline, '
              'fonts and gaps bump up again.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;

  const _Badge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final on =
        value == 'on' ||
        value == '8px' ||
        value == '4px' ||
        value == '15px' ||
        value == '13px' ||
        value == 'inline' ||
        value == 'above';
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
