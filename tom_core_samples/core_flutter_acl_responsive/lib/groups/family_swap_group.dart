/// Family swap — Material ↔ Cupertino at a width threshold, shared state.
///
/// Two [FamilyForm] instances are pre-built once (one [TomFormFieldFamily.material],
/// one [TomFormFieldFamily.cupertino]) and bound to the **same** [ResponsiveProfile].
/// A `LayoutBuilder` renders whichever matches the 700 px breakpoint; the
/// page-root [TomFormStyleScope] flips the form *style* (Material3 ↔ Cupertino)
/// at the same threshold via [TomFormStyleScope.styleBpOverrides]. Because both
/// forms share one entity, edits survive the swap. Re-cast from the verified
/// `tom_flutter_form_test` `demo_p_family_swap_breakpoint`.
library;

import 'package:flutter/material.dart';
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
  summary:
      'Two forms — one Material, one Cupertino — bound to one shared '
      'entity. The 700px breakpoint picks which renders; styleBpOverrides flips '
      'the form style to match. Edits survive the swap.',
  icon: Icons.swap_horiz_outlined,
  cells: (context) => [
    ShowcaseCell(
      title: 'Material ↔ Cupertino at 700px',
      note:
          'Resize across 700px: the whole field family swaps, yet the shared '
          'state panel keeps every value — both forms bind the same entity.',
      code:
          '// Pre-build one form per family, both bound to ONE entity:\n'
          'final material  = FamilyForm(family: TomFormFieldFamily.material);\n'
          'final cupertino = FamilyForm(family: TomFormFieldFamily.cupertino);\n'
          'material.bind(shared); cupertino.bind(shared);\n\n'
          '// (minWidth, style): highest minWidth <= width wins, so the\n'
          '// override applies at/above 700 where the Material family renders.\n'
          'TomFormStyleScope(\n'
          '  style: TomCupertinoFormStyle.cupertino,\n'
          '  styleBpOverrides: [(700, TomFormStyle.material3)],\n'
          '  child: TomLayoutBuilder(builder: (ctx, c) {\n'
          '    final wide = c.maxWidth >= 700;\n'
          '    final form = wide ? material : cupertino;\n'
          '    return TomColumn(children: [\n'
          '      form.fullName.widget,\n'
          '      form.quantity.widget,\n'
          '      form.ratio.widget,\n'
          '      form.notifyMe.widget,\n'
          '      form.eventDate.widget,\n'
          '    ]);\n'
          '  }),\n'
          ')',
      // The demo exists to cross this width; a narrower preview could only
      // ever show the Cupertino side.
      childMinWidth: familySwapBreakpoint,
      child: FamilySwapDemo(),
    ),
  ],
);

/// A self-contained family-swap surface: two pre-built forms on one shared
/// entity, the active one chosen by the 700 px breakpoint, with a badge and a
/// shared-state panel that proves values survive the swap.
// Why: extends [TomStatefulWidget]/[TomState] (not raw) so the demo payload
// conforms to G-UI-2 and its layout uses Tom primitives. No tomId/resources →
// scope bases, which are non-const (construction reads [TomScope.current]).
class FamilySwapDemo extends TomStatefulWidget {
  FamilySwapDemo({super.key});

  @override
  TomState<FamilySwapDemo> createState() => _FamilySwapDemoState();
}

class _FamilySwapDemoState extends TomState<FamilySwapDemo> {
  late final FamilyForm _materialForm;
  late final FamilyForm _cupertinoForm;

  @override
  void initState() {
    super.initState();
    _materialForm = TomScope.withScope(
      'familySwap-material',
      () => FamilyForm(family: TomFormFieldFamily.material),
    );
    _cupertinoForm = TomScope.withScope(
      'familySwap-cupertino',
      () => FamilyForm(family: TomFormFieldFamily.cupertino),
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
  Widget buildContent(BuildContext context) {
    // Why the Cupertino style is the *base* and Material3 the override:
    // `styleBpOverrides` entries are `(minWidth, style)` and the highest
    // `minWidth <= width` wins, so an entry keyed at the breakpoint applies on
    // the **wide** side of it — the side where the Material family renders.
    // Keying Cupertino there would dress the Material form in Cupertino chrome
    // and leave the Cupertino form under Material3 below the breakpoint, i.e.
    // the inverse of the swap. The base style covers everything below the
    // lowest override, which is exactly the narrow, Cupertino-family side.
    return TomFormStyleScope(
      style: TomCupertinoFormStyle.cupertino,
      styleBpOverrides: [(familySwapBreakpoint, TomFormStyle.material3)],
      child: TomLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= familySwapBreakpoint;
          final form = wide ? _materialForm : _cupertinoForm;
          return TomColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BreakpointBadge(width: width, family: form.family),
              TomSizedBox(height: 12),
              _FormColumn(form: form),
              TomSizedBox(height: 12),
              _StatePanel(form: _materialForm),
            ],
          );
        },
      ),
    );
  }
}

// Why: scope-participating layout wrapper (no tomId/resources) →
// [TomStatelessWidget], non-const; raw layout primitives swapped for Tom ones.
class _BreakpointBadge extends TomStatelessWidget {
  _BreakpointBadge({required this.width, required this.family});

  final double width;
  final TomFormFieldFamily family;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final wide = width >= familySwapBreakpoint;
    return TomContainer(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TomRow(
        children: [
          TomIcon(
            icon: wide
                ? Icons.desktop_mac_outlined
                : Icons.phone_iphone_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          TomSizedBox(width: 8),
          TomExpanded(
            child: TomText(
              text:
                  'width: ${width.toStringAsFixed(0)} px '
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

// Why: scope-participating layout wrapper (no tomId/resources) →
// [TomStatelessWidget], non-const; raw layout primitives swapped for Tom ones.
class _FormColumn extends TomStatelessWidget {
  _FormColumn({required this.form});

  final FamilyForm form;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return TomCard(
      child: TomPadding(
        padding: const EdgeInsets.all(12),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TomPadding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TomText(
                text: 'Active family: ${form.family.kind.name}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            form.fullName.widget,
            TomSizedBox(height: 8),
            form.quantity.widget,
            TomSizedBox(height: 8),
            form.ratio.widget,
            TomSizedBox(height: 8),
            form.notifyMe.widget,
            TomSizedBox(height: 8),
            form.eventDate.widget,
          ],
        ),
      ),
    );
  }
}

/// Reads the shared entity through the Material form's observables (the same
/// `TomObject`s the Cupertino form binds), proving the single source of truth.
// Why: scope-participating layout wrapper (no tomId/resources) →
// [TomStatelessWidget], non-const; raw layout primitives swapped for Tom ones.
class _StatePanel extends TomStatelessWidget {
  _StatePanel({required this.form});

  final FamilyForm form;

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    String dateStr(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return TomCard(
      color: theme.colorScheme.surfaceContainerHighest,
      child: TomPadding(
        padding: const EdgeInsets.all(12),
        child: TomColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TomPadding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TomText(
                text: 'Shared state (ResponsiveProfile)',
                style: theme.textTheme.titleSmall,
              ),
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
                return TomColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (name, value) in rows)
                      TomPadding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: TomRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TomSizedBox(
                              width: 110,
                              child: TomText(
                                text: name,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            TomExpanded(
                              child: TomText(
                                text: value,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
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
