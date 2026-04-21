/// Demo P — `FormFieldFamily` swap by breakpoint (Phase 5c).
///
/// One [Phase5cFamilyState] feeds two `Phase5cFamilyForm` instances:
/// one constructed against [FormFieldFamily.material] and one against
/// [FormFieldFamily.cupertino]. A [LayoutBuilder] picks which form to
/// render based on the 700 px breakpoint:
///
///   * `width >= 700 px` → Material form, light + airy themeSpec
///   * `width <  700 px` → Cupertino form, dense + dark themeSpec
///
/// The page-root `TomFormStyleScope` uses [TomFormStyleScope.styleBpOverrides]
/// to swap the *form style* (Material3 ↔ Cupertino) at the same threshold,
/// so the underlying anatomy (label/error/description gaps, radii)
/// matches the family being shown. A second-layer `themeSpec` swap
/// (light/airy ↔ dense/dark) layers on top, giving the demo two
/// simultaneous breakpoint-driven transformations.
///
/// State survives the swap because both forms are pre-built once in
/// `initState` and bound to the same shared `Phase5cFamilyState`. Edits
/// in one family flow into the state, and the other family's fields
/// reflect them on the next build (live, via observers).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/phase5_demo_forms.dart';
import '../panels/info_panel.dart';
import '../state/phase5_state.dart';

const double _phase5cBreakpoint = 700;

class DemoPFamilySwapBreakpoint extends StatefulWidget {
  const DemoPFamilySwapBreakpoint({super.key});

  @override
  State<DemoPFamilySwapBreakpoint> createState() =>
      _DemoPFamilySwapBreakpointState();
}

class _DemoPFamilySwapBreakpointState extends State<DemoPFamilySwapBreakpoint> {
  late final Phase5cFamilyForm _materialForm;
  late final Phase5cFamilyForm _cupertinoForm;

  @override
  void initState() {
    super.initState();
    _materialForm = TomScope.withScope(
      'demoP-material',
      () => Phase5cFamilyForm(family: FormFieldFamily.material),
    );
    _cupertinoForm = TomScope.withScope(
      'demoP-cupertino',
      () => Phase5cFamilyForm(family: FormFieldFamily.cupertino),
    );

    // Both forms share one TomClass — bind() on each so observable
    // values round-trip across the swap.
    _materialForm.bind(phase5cFamilyState);
    _cupertinoForm.bind(phase5cFamilyState);
  }

  @override
  void dispose() {
    _materialForm.dispose();
    _cupertinoForm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo P — FormFieldFamily swap by breakpoint (Phase 5c)',
      child: TomFormStyleScope(
        // Outer style swap by breakpoint. Width >= 700 px → Material3,
        // width < 700 px → Cupertino. The styleBpOverrides API lets the
        // scope itself flip without a setState in this widget tree.
        style: const TomFormStyle(),
        styleBpOverrides: [
          (_phase5cBreakpoint, TomCupertinoFormStyle.cupertino),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _phase5cBreakpoint;
            final family = isWide
                ? FormFieldFamily.material
                : FormFieldFamily.cupertino;
            final form = isWide ? _materialForm : _cupertinoForm;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBpBadge(context, constraints.maxWidth, family),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _formColumn(context, form)),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 280,
                                child: _statePanel(context),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _formColumn(context, form),
                              const SizedBox(height: 12),
                              _statePanel(context),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBpBadge(
      BuildContext context, double width, FormFieldFamily family) {
    final theme = Theme.of(context);
    final wide = width >= _phase5cBreakpoint;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            wide
                ? Icons.desktop_mac_outlined
                : CupertinoIcons.device_phone_portrait,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
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

  Widget _formColumn(BuildContext context, Phase5cFamilyForm form) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              context,
              'Active family: ${form.family.kind.name}',
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

  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _statePanel(BuildContext context) {
    return InfoPanel(
      title: 'Shared state (Phase5cFamilyState)',
      children: [
        TomMultiObservableBuilder(
          observables: [
            _materialForm.fullName,
            _materialForm.quantity,
            _materialForm.ratio,
            _materialForm.notifyMe,
            _materialForm.eventDate,
          ],
          builder: (context) {
            final theme = Theme.of(context);
            String dateStr(DateTime d) =>
                '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}';
            final rows = <(String, String)>[
              ('fullName', _materialForm.fullName.get()),
              ('quantity', '${_materialForm.quantity.get()}'),
              ('ratio', _materialForm.ratio.get().toStringAsFixed(2)),
              ('notifyMe', '${_materialForm.notifyMe.get()}'),
              ('eventDate', dateStr(_materialForm.eventDate.get())),
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
                          child:
                              Text(name, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          child: Text(
                            value,
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
    );
  }
}
