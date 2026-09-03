// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../common/demo_scaffold.dart';
import '../forms/project_brief_form.dart';
import '../panels/field_state_table.dart';
import '../panels/info_panel.dart';
import '../state/project_brief_state.dart';
import 'demo_g_breakpoint_scenarios.dart'
    show buildComplexFormPane, clearProjectBriefForm, projectBriefActionBar;

// ---------------------------------------------------------------------------
// Demo H — Complex Authorization + Responsive Layout Overlay (Phase 2)
// ---------------------------------------------------------------------------

/// Reuses the **exact same** complex form pane Demo G ships — all four style
/// presets, all four theme presets, and every ACL breakpoint API — and
/// overlays per-field / per-section / form-level authorization on top so
/// the re-layout and the auth pipeline are exercised together.
///
/// The right-hand panel carries:
///
///   * **Form-level auth** — narrows every field under `demoH.projectBrief`.
///   * **Section auth** — per-section dropdowns for classification,
///     scope, classic, people (lead), people (reviewer), longform.
///   * **Spot-field auth** — focused dropdowns for a handful of fields
///     (priority, budget, deadline) so widget-type swaps can be seen
///     going read-only / disabled / hidden at each width band.
///   * **Field-state table** — live effectiveAuthState per field for
///     every nested form, so you can verify the auth + breakpoint
///     interactions by reading values, not by squinting at pixels.
class DemoHComplexAuthorization extends StatefulWidget {
  const DemoHComplexAuthorization({super.key});

  @override
  State<DemoHComplexAuthorization> createState() =>
      _DemoHComplexAuthorizationState();
}

class _DemoHComplexAuthorizationState extends State<DemoHComplexAuthorization> {
  late final _DemoHAdapter _adapter;
  late final ProjectBriefForm _form;
  double _widthFraction = 0.9;

  // Mirrors the adapter's state so the dropdowns re-render with the right
  // selection even after the adapter accepts an explicit full-state.
  final Map<String, TomAuthState> _rules = {
    'demoH.projectBrief': TomAuthState.full,
    'demoH.projectBrief.classification': TomAuthState.full,
    'demoH.projectBrief.scope': TomAuthState.full,
    'demoH.projectBrief.classic': TomAuthState.full,
    'demoH.projectBrief.longform': TomAuthState.full,
    'demoH.projectBrief.lead': TomAuthState.full,
    'demoH.projectBrief.reviewer': TomAuthState.full,
    'demoH.projectBrief.priority': TomAuthState.full,
    'demoH.projectBrief.budget': TomAuthState.full,
    'demoH.projectBrief.deadline': TomAuthState.full,
  };

  @override
  void initState() {
    super.initState();
    _adapter = _DemoHAdapter();
    TomAuthorization.adapter = _adapter;
    _form = TomScope.withScope('demoH', () => ProjectBriefForm());
    _form.bind(phase2ProjectBriefState);
    _form.lead.bind(phase2ProjectBriefState.lead);
    _form.reviewer.bind(phase2ProjectBriefState.reviewer);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  // No form listener: FieldStateTable already rebuilds off form.changes, and
  // auth dropdowns carry their own setState via [_setAuth]. An outer
  // setState on every FieldValueChangedEvent would rebuild the full demo
  // subtree per keystroke, and the resulting InheritedWidget churn wipes
  // the TextField FocusNode after the first character (same root cause
  // that was fixed for Demo G).

  Future<void> _save() async {
    final ok = await _form.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saved — phase2ProjectBriefState updated.'
              : 'Validation failed or blocked by auth — check field state.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clear() {
    clearProjectBriefForm(_form);
  }

  void _setAuth(String path, TomAuthState state) {
    setState(() {
      _rules[path] = state;
      if (state == TomAuthState.full) {
        _adapter.removeRule(path);
      } else {
        _adapter.setRule(path, state);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo H — Complex Authorization + Responsive Layout',
      child: LayoutBuilder(
        builder: (context, outer) {
          final isWide = outer.maxWidth >= 900;
          final form = _buildFormColumn(context, outer);
          final info = _buildInfoColumn(context);
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: SingleChildScrollView(child: form)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: SingleChildScrollView(child: info)),
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

  Widget _buildFormColumn(BuildContext context, BoxConstraints outer) {
    final isWide = outer.maxWidth >= 900;
    final maxPaneWidth = isWide ? outer.maxWidth * 0.6 : outer.maxWidth;
    final paneWidth = (maxPaneWidth * _widthFraction).clamp(
      300.0,
      maxPaneWidth,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _splitterCard(context, maxPaneWidth, paneWidth),
        const SizedBox(height: 12),
        projectBriefActionBar(context: context, onClear: _clear, onSave: _save),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: paneWidth,
            child: buildComplexFormPane(
              context: context,
              form: _form,
              state: phase2ProjectBriefState,
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
            const Text(
              'Every feature from Demo G — the four-band style '
              'preset swap, the four-band theme swap, the full set of '
              'ACL breakpoints, and the responsive widget-type swap '
              'on priority — plus a per-field / per-section / form-level '
              'authorization overlay.',
            ),
            SizedBox(height: 6),
            Text(
              'Drive any auth dropdown on the right and watch the form '
              'respond live: fields go read-only, disabled, or disappear. '
              'Drag the splitter to verify the auth state survives the '
              're-layout that fires as the pane crosses 400 / 800 / 1200 '
              '/ 1600 px.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitterCard(
    BuildContext context,
    double maxPaneWidth,
    double paneWidth,
  ) {
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
              min: 300.0 / maxPaneWidth.clamp(301.0, double.infinity),
              max: 1.0,
              onChanged: (v) => setState(() => _widthFraction = v),
            ),
            const Text(
              'Breakpoints at 400 / 800 / 1200 / 1600 px.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Authorization controls',
          children: [
            const InfoPanelHeading('Form-level ceiling'),
            _authDropdown('demoH.projectBrief'),
            const InfoPanelHeading('Sections'),
            _sectionRow(
              context,
              'Classification',
              'demoH.projectBrief.classification',
            ),
            _sectionRow(context, 'Scope', 'demoH.projectBrief.scope'),
            _sectionRow(context, 'Classic pair', 'demoH.projectBrief.classic'),
            _sectionRow(context, 'Longform', 'demoH.projectBrief.longform'),
            _sectionRow(context, 'Lead subform', 'demoH.projectBrief.lead'),
            _sectionRow(
              context,
              'Reviewer subform',
              'demoH.projectBrief.reviewer',
            ),
            const InfoPanelHeading('Spot fields'),
            _sectionRow(context, 'Priority', 'demoH.projectBrief.priority'),
            _sectionRow(context, 'Budget', 'demoH.projectBrief.budget'),
            _sectionRow(context, 'Deadline', 'demoH.projectBrief.deadline'),
          ],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'Field state (live)',
          children: [
            FieldStateTable(forms: [_form, _form.lead, _form.reviewer]),
          ],
        ),
      ],
    );
  }

  Widget _sectionRow(BuildContext context, String label, String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          SelectableText(
            path,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          _authDropdown(path),
        ],
      ),
    );
  }

  Widget _authDropdown(String path) {
    final current = _rules[path] ?? TomAuthState.full;
    return DropdownButton<TomAuthState>(
      isExpanded: true,
      value: current,
      items: [
        for (final s in TomAuthState.values)
          DropdownMenuItem(value: s, child: Text(s.name)),
      ],
      onChanged: (v) {
        if (v != null) _setAuth(path, v);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Adapter — path-prefix match so any section / form-level entry narrows
// everything beneath it.
// ---------------------------------------------------------------------------

class _DemoHAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> _rules = {};

  @override
  TomAuthState resolveAuth(String resourceKeyPath) {
    if (_rules.containsKey(resourceKeyPath)) return _rules[resourceKeyPath]!;
    final parts = resourceKeyPath.split('.');
    for (var i = parts.length - 1; i > 0; i--) {
      final parent = parts.sublist(0, i).join('.');
      if (_rules.containsKey(parent)) return _rules[parent]!;
    }
    return TomAuthState.full;
  }

  void setRule(String path, TomAuthState s) => _rules[path] = s;
  void removeRule(String path) => _rules.remove(path);
}
