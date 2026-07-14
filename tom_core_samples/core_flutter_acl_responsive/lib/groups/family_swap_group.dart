/// Family swap — Material ↔ Cupertino at a width threshold, shared state.
///
/// Two [FamilyForm] instances are pre-built once (one [FormFieldFamily.material],
/// one [FormFieldFamily.cupertino]) and bound to the **same** [ResponsiveProfile].
/// A `LayoutBuilder` renders whichever matches the 700 px breakpoint; the
/// page-root [TomFormStyleScope] flips the form *style* (Material3 ↔ Cupertino)
/// at the same threshold via [TomFormStyleScope.styleBpOverrides]. Because both
/// forms share one entity, edits survive the swap. Re-cast from the verified
/// `tom_flutter_form_test` `demo_p_family_swap_breakpoint`.
library;

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/showcase_cell.dart';
import '../common/showcase_section.dart';
import '../domain/responsive_entities.dart';
import '../forms/family_form.dart';

/// The width below which the family flips from Material to Cupertino.
const double familySwapBreakpoint = 700;

/// The family-swap mechanism group.
final ShowcaseGroup familySwapGroup = ShowcaseGroup(
  id: 'family_swap',
  title: 'Family swap',
  summary: 'Two forms — one Material, one Cupertino — bound to one shared '
      'entity. The 700px breakpoint picks which renders; styleBpOverrides flips '
      'the form style to match. Edits survive the swap.',
  icon: Icons.swap_horiz_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Material ↔ Cupertino at 700px',
      note: 'Resize across 700px: the whole field family swaps, yet the shared '
          'state panel keeps every value — both forms bind the same entity.',
      code: '// Pre-build one form per family, both bound to ONE entity:\n'
          'final material  = FamilyForm(family: FormFieldFamily.material);\n'
          'final cupertino = FamilyForm(family: FormFieldFamily.cupertino);\n'
          'material.bind(shared); cupertino.bind(shared);\n\n'
          'TomFormStyleScope(\n'
          '  style: const TomFormStyle(),\n'
          '  styleBpOverrides: [(700, TomCupertinoFormStyle.cupertino)],\n'
          '  child: LayoutBuilder(builder: (ctx, c) {\n'
          '    final wide = c.maxWidth >= 700;\n'
          '    return (wide ? material : cupertino).buildColumn();\n'
          '  }),\n'
          ')',
      child: FamilySwapDemo(),
    ),
  ],
);

/// A self-contained family-swap surface: two pre-built forms on one shared
/// entity, the active one chosen by the 700 px breakpoint, with a badge and a
/// shared-state panel that proves values survive the swap.
class FamilySwapDemo extends StatefulWidget {
  const FamilySwapDemo({super.key});

  @override
  State<FamilySwapDemo> createState() => _FamilySwapDemoState();
}

class _FamilySwapDemoState extends State<FamilySwapDemo> {
  late final FamilyForm _materialForm;
  late final FamilyForm _cupertinoForm;

  @override
  void initState() {
    super.initState();
    _materialForm = TomScope.withScope(
      'familySwap-material',
      () => FamilyForm(family: FormFieldFamily.material),
    );
    _cupertinoForm = TomScope.withScope(
      'familySwap-cupertino',
      () => FamilyForm(family: FormFieldFamily.cupertino),
    );
    // Both forms share one entity so observable values round-trip across the
    // swap.
    final shared = ResponsiveProfile();
    _materialForm.bind(shared);
    _cupertinoForm.bind(shared);
  }

  @override
  void dispose() {
    _materialForm.dispose();
    _cupertinoForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TomFormStyleScope(
      style: const TomFormStyle(),
      styleBpOverrides: [
        (familySwapBreakpoint, TomCupertinoFormStyle.cupertino),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= familySwapBreakpoint;
          final form = wide ? _materialForm : _cupertinoForm;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BreakpointBadge(width: width, family: form.family),
              const SizedBox(height: 12),
              _FormColumn(form: form),
              const SizedBox(height: 12),
              _StatePanel(form: _materialForm),
            ],
          );
        },
      ),
    );
  }
}

class _BreakpointBadge extends StatelessWidget {
  const _BreakpointBadge({required this.width, required this.family});

  final double width;
  final FormFieldFamily family;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = width >= familySwapBreakpoint;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            wide ? Icons.desktop_mac_outlined : Icons.phone_iphone_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TomText(
              text: 'width: ${width.toStringAsFixed(0)} px '
                  '→ family: ${family.kind.name} '
                  '(${wide ? "wide → Material" : "narrow → Cupertino"})',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.form});

  final FamilyForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TomText(
                text: 'Active family: ${form.family.kind.name}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            form.fullName.widget,
            const SizedBox(height: 8),
            form.quantity.widget,
            const SizedBox(height: 8),
            form.ratio.widget,
            const SizedBox(height: 8),
            form.notifyMe.widget,
            const SizedBox(height: 8),
            form.eventDate.widget,
          ],
        ),
      ),
    );
  }
}

/// Reads the shared entity through the Material form's observables (the same
/// `TomObject`s the Cupertino form binds), proving the single source of truth.
class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.form});

  final FamilyForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String dateStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return TomCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TomText(
                  text: 'Shared state (ResponsiveProfile)',
                  style: theme.textTheme.titleSmall),
            ),
            TomMultiObservableBuilder(
              observables: [
                form.fullName,
                form.quantity,
                form.ratio,
                form.notifyMe,
                form.eventDate,
              ],
              builder: (context) {
                final rows = <(String, String)>[
                  ('fullName', form.fullName.get()),
                  ('quantity', '${form.quantity.get()}'),
                  ('ratio', form.ratio.get().toStringAsFixed(2)),
                  ('notifyMe', '${form.notifyMe.get()}'),
                  ('eventDate', dateStr(form.eventDate.get())),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (name, value) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: TomText(
                                  text: name,
                                  style: theme.textTheme.bodySmall),
                            ),
                            Expanded(
                              child: TomText(
                                text: value,
                                style: theme.textTheme.bodySmall
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
        ),
      ),
    );
  }
}
