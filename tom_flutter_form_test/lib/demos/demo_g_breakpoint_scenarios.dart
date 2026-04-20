import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/validation_form.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';

// ---------------------------------------------------------------------------
// Demo G — Complex Breakpoint Scenarios (Phase 2)
// ---------------------------------------------------------------------------

/// Two-column layout exercising the Phase 2 breakpoint / nested-scope
/// features described in the spec:
///
///   * Outer `TomFormStyleScope` with three-band `styleBpOverrides`
///     (compact / comfortable / spacious) — gap, padding, and border react
///     live as the form pane crosses the thresholds.
///   * Nested `TomFormStyleScope(style: TomFormStyle.compact, …)` around
///     one panel so per-section styling is visible against sibling panels
///     that inherit the outer scope.
///   * Drag-to-resize splitter so the scope width is observable without
///     having to resize the window.
///
/// Uses only Phase 1 fields (TomFormStringInput). The boolean /
/// multi-select breakpoints from the spec will slot into this scaffold
/// once the Phase 2 field widgets land.
class DemoGBreakpointScenarios extends StatefulWidget {
  const DemoGBreakpointScenarios({super.key});

  @override
  State<DemoGBreakpointScenarios> createState() =>
      _DemoGBreakpointScenariosState();
}

class _DemoGBreakpointScenariosState extends State<DemoGBreakpointScenarios> {
  late final ValidationForm _form;
  double _widthFraction = 0.8;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoG', () => ValidationForm());
    _form.bind(phase1ValidationState);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo G — Complex Breakpoint Scenarios',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _buildFormColumn(context, constraints);
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

  Widget _buildFormColumn(BuildContext context, BoxConstraints constraints) {
    // Reserve room for the right-hand info panel (2/5 of width) when the
    // two-column layout is active.
    final isWide = constraints.maxWidth >= 900;
    final maxPaneWidth = isWide ? constraints.maxWidth * 0.6 : constraints.maxWidth;
    final paneWidth = (maxPaneWidth * _widthFraction).clamp(240.0, maxPaneWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _splitterCard(context, maxPaneWidth, paneWidth),
        const SizedBox(height: 12),
        _activeBandBadge(context, paneWidth),
        const SizedBox(height: 12),

        // Outer scope with three-band styleBpOverrides.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: paneWidth,
            child: TomFormStyleScope(
              style: TomFormStyle.material3,
              styleBpOverrides: [
                (TomBreakpoint.tablet, TomFormStyle.compact),
                (TomBreakpoint.desktop, TomFormStyle.bordered),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section(
                    context,
                    'Outer scope — style swaps by width',
                    _buildOuterForm(context),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    context,
                    'Nested scope — always compact (style override)',
                    TomFormStyleScope(
                      style: TomFormStyle.compact,
                      child: _buildNestedForm(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            const _Bullet('Outer TomFormStyleScope has three-band '
                'styleBpOverrides: material3 → compact at tablet → bordered '
                'at desktop. Resize the pane below the active-band badge '
                'to see the swap.'),
            const _Bullet('A nested TomFormStyleScope with the compact '
                'preset renders alongside — stays compact regardless of '
                'pane width, proving sibling panels stay independent.'),
            const _Bullet('Phase 2 will add themeSpecBpOverrides and ACL '
                'layout breakpoints to this same scaffold. The right-hand '
                'info column already tracks pane width and the active '
                'band.'),
          ],
        ),
      ),
    );
  }

  Widget _splitterCard(
      BuildContext context, double maxPaneWidth, double paneWidth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Form pane width',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Text('${paneWidth.toStringAsFixed(0)} px',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            Slider(
              value: _widthFraction,
              min: 240.0 / maxPaneWidth.clamp(241.0, double.infinity),
              max: 1.0,
              onChanged: (v) => setState(() => _widthFraction = v),
            ),
            Text(
              'Crosses TomBreakpoint.mobile (${TomBreakpoint.mobile.toStringAsFixed(0)}), '
              '.tablet (${TomBreakpoint.tablet.toStringAsFixed(0)}), '
              '.desktop (${TomBreakpoint.desktop.toStringAsFixed(0)}).',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBandBadge(BuildContext context, double width) {
    String band;
    if (width >= TomBreakpoint.desktop) {
      band = '≥ desktop — bordered preset';
    } else if (width >= TomBreakpoint.tablet) {
      band = '≥ tablet — compact preset';
    } else {
      band = '< tablet — material3 (base)';
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Active band → $band',
            style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOuterForm(BuildContext context) {
    return TomAclBuilder(
      id: 'demoGOuter',
      elementProvider: _form,
    )
        .setAclExpandXDefault(true)
        .append((p) => p.username.widget)
        .newRow()
        .append((p) => p.email.widget)
        .build(context);
  }

  Widget _buildNestedForm(BuildContext context) {
    return TomAclBuilder(
      id: 'demoGNested',
      elementProvider: _form,
    )
        .setAclExpandXDefault(true)
        .append((p) => p.password.widget)
        .append((p) => p.confirmPassword.widget, dist: 16)
        .build(context);
  }

  Widget _buildInfoColumn(BuildContext context) {
    return InfoPanel(
      title: 'Active breakpoint',
      children: [
        Text(
          'Pane width is controlled by the slider above. The outer scope '
          'swaps presets at TomBreakpoint.tablet and .desktop; the nested '
          'scope stays on compact regardless.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const InfoPanelHeading('Breakpoints'),
        _kv(context, 'mobile',
            '${TomBreakpoint.mobile.toStringAsFixed(0)} px'),
        _kv(context, 'tablet',
            '${TomBreakpoint.tablet.toStringAsFixed(0)} px'),
        _kv(context, 'desktop',
            '${TomBreakpoint.desktop.toStringAsFixed(0)} px'),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(k, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
              v,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      );
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
