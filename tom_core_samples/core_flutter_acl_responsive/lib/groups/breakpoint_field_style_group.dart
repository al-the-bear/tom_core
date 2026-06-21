/// Breakpoint field style — the same form re-styles itself per width tier.
///
/// A [TomFormStyleScope] wraps the form and publishes the available width via
/// its internal `LayoutBuilder`. Every layout property on [TomFieldStyle] has a
/// `*BpOverrides` twin — a `(minWidth, value)` list — so the field anatomy
/// (label placement, font sizes, gaps, error border/icon) resolves against the
/// live width with **no rebuild branching in app code**. The badges echo the
/// resolved tier so the behaviour is observable (and testable). Re-cast from the
/// verified `tom_flutter_form_test` `demo_8_breakpoints`.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/responsive_entities.dart';
import '../forms/company_form.dart';

/// The breakpoint-field-style mechanism group.
final ShowcaseGroup breakpointFieldStyleGroup = ShowcaseGroup(
  id: 'breakpoint_field_style',
  title: 'Breakpoint field style',
  summary: 'TomFormStyleScope publishes the available width; TomFieldStyle '
      "*BpOverrides re-style the same form per tier — no app-code branching. "
      'Resize the window: label, fonts, gaps and error chrome react live.',
  icon: Icons.format_size_outlined,
  cells: (context) => const [
    ShowcaseCell(
      title: 'Width-reactive field anatomy',
      note: 'Crossing 400px: label floating → above, fonts bump, gaps grow, '
          'error border turns on. Crossing 500px: error icon appears. '
          'Crossing 700px: label above → inline, fonts/gaps bump again.',
      code: 'TomFormStyleScope(\n'
          '  style: TomFormStyle(\n'
          '    defaults: TomFieldStyle(\n'
          '      labelPlacement: LabelPlacement.floating,\n'
          '      labelPlacementBpOverrides: [\n'
          '        (400, LabelPlacement.above),\n'
          '        (700, LabelPlacement.inline),\n'
          '      ],\n'
          '      // …labelStyle / gaps / errorBorder / errorIcon overrides…\n'
          '    ),\n'
          '  ),\n'
          '  child: TomAclBuilder(id: "bp", elementProvider: form)\n'
          '      .append((p) => p.name.widget).build(context),\n'
          ')',
      child: BreakpointFieldStyleDemo(),
    ),
  ],
);

/// A self-contained, width-reactive form whose field style resolves per tier
/// from a single [TomFormStyleScope]. The badge row reads back the resolved
/// tier so the behaviour is observable both in the app and in tests.
class BreakpointFieldStyleDemo extends StatefulWidget {
  const BreakpointFieldStyleDemo({super.key});

  @override
  State<BreakpointFieldStyleDemo> createState() =>
      _BreakpointFieldStyleDemoState();
}

class _BreakpointFieldStyleDemoState extends State<BreakpointFieldStyleDemo> {
  late final CompanyForm _form;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('bpFieldStyle', CompanyForm.new);
    _form.bind(CompanyProfile());
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  /// Breakpoint-aware style. The override lists ride on [TomFieldStyle]; the
  /// scope feeds the live width into `resolveFieldStyle`.
  TomFormStyle get _style => TomFormStyle(
        defaults: const TomFieldStyle(
          labelPlacement: LabelPlacement.floating,
          labelPlacementBpOverrides: [
            (400, LabelPlacement.above),
            (700, LabelPlacement.inline),
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
          labelFieldGap: 2,
          labelFieldGapBpOverrides: [(400, 4.0), (700, 8.0)],
          errorFieldGap: 2,
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
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BadgeRow(width: width),
            const SizedBox(height: 12),
            TomFormStyleScope(
              style: _style,
              child: TomAclBuilder(id: 'bpFieldStyleAcl', elementProvider: _form)
                  .setAclDefaultRowVerticalAlignment(AclRowCrossAlignment.top)
                  .setAclExpandXDefault(true)
                  .append((p) => p.name.widget)
                  .newRow()
                  .append((p) => p.taxId.widget)
                  .newRow()
                  .append((p) => p.website.widget)
                  .build(context),
            ),
          ],
        );
      },
    );
  }
}

/// Echoes the resolved breakpoint tier as a `Wrap` of `label: value` badges.
/// The resolution mirrors the override lists in [_style] so the badges are the
/// ground truth for both the reader and the tests.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final gap = width >= 700 ? '8px' : (width >= 400 ? '4px' : '2px');
    final border = width >= 400 ? 'on' : 'off';
    final icon = width >= 500 ? 'on' : 'off';
    final label = width >= 700 ? 'inline' : (width >= 400 ? 'above' : 'floating');
    final font = width >= 700 ? '15px' : (width >= 400 ? '13px' : '11px');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (l, v) in <(String, String)>[
          ('labelPlacement', label),
          ('labelStyle', font),
          ('hintStyle', font),
          ('labelFieldGap', gap),
          ('errorFieldGap', gap),
          ('errorBorderEnabled', border),
          ('errorIconEnabled', icon),
        ])
          _Badge(label: l, value: v),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
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
