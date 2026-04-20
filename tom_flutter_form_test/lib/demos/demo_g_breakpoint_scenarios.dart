// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/project_brief_form.dart';
import '../panels/info_panel.dart';
import '../state/project_brief_state.dart';

// ---------------------------------------------------------------------------
// Demo G — Complex Breakpoint & Theming Scenarios (Phase 2)
// ---------------------------------------------------------------------------

/// Drives the entire [ProjectBriefForm] through four layered breakpoint
/// regimes at 400 / 800 / 1200 / 1600 px:
///
///   1. **Style preset** — the `TomFormStyleScope` swaps `TomFormStyle`
///      across widths: bordered (≥1600) → material3 with a 3 px outline
///      (≥1200) → smaller-typography material3 (≥800) → compact + 1 px
///      outline (≥400) → compact fallback.
///   2. **ThemeData** — same width thresholds swap colours and font
///      family: deep-blue Georgia (≥1600) → teal Georgia (≥1200) →
///      purple Roboto (≥800) → indigo monospace (≥400) → orange
///      monospace fallback. `themeBpOverrides` on the scope keeps the
///      swap inside `withTheme()`'s automatic recomputation.
///   3. **ACL breakpoints** — [TomAclBuilder] exercises every breakpoint
///      API in the same layout: `addRowBreakpoint` splits the
///      "classification" row at 800 and 400, `setAclDefaultAppendGap`
///      with `gapBpOverrides` scales gaps per width band, and
///      `setAclDefaultRowHeight` with `heightBpOverrides` drives row
///      height.
///   4. **Responsive widget swap** — the "priority" field renders as a
///      `SegmentedButton` above 1000 px, then collapses into the
///      spec-aligned `TomFormStringDropdown` below; both bind to the
///      same `form.priority.setValue(...)` so the observable channel is
///      single-source.
///
/// A drag-to-resize splitter drives the form pane width independently of
/// the window size, so the transitions are observable without having to
/// resize Flutter's outer window.
class DemoGBreakpointScenarios extends StatefulWidget {
  const DemoGBreakpointScenarios({super.key});

  @override
  State<DemoGBreakpointScenarios> createState() =>
      _DemoGBreakpointScenariosState();
}

class _DemoGBreakpointScenariosState extends State<DemoGBreakpointScenarios> {
  late final ProjectBriefForm _form;
  double _widthFraction = 0.9;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoG', () => ProjectBriefForm());
    _form.bind(phase2ProjectBriefState);
    _form.lead.bind(phase2ProjectBriefState.lead);
    _form.reviewer.bind(phase2ProjectBriefState.reviewer);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo G — Complex Breakpoint & Theming Scenarios',
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

  Widget _buildFormColumn(BuildContext context, BoxConstraints outer) {
    final isWide = outer.maxWidth >= 900;
    final maxPaneWidth =
        isWide ? outer.maxWidth * 0.6 : outer.maxWidth;
    final paneWidth =
        (maxPaneWidth * _widthFraction).clamp(300.0, maxPaneWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _splitterCard(context, maxPaneWidth, paneWidth),
        const SizedBox(height: 12),
        _activeBandBadge(context, paneWidth),
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
            const _Bullet('Four style presets swap at 400 / 800 / 1200 / '
                '1600 px via styleBpOverrides (compact+1px → smaller fonts '
                '→ material3+3px → bordered).'),
            const _Bullet('Four themes swap at the same widths via '
                'themeBpOverrides — colour palette and font family both '
                'change. withTheme() picks the new theme up automatically.'),
            const _Bullet('ACL exercises every breakpoint API: '
                'addRowBreakpoint splits the classification and identity '
                'rows at 800 and 400; setAclDefaultAppendGap scales gaps '
                'per band; setAclDefaultRowHeight drives section row '
                'heights; nested subforms stack below 1000.'),
            const _Bullet('The "priority" field is rendered as a '
                'SegmentedButton above 1000 px and collapses to a '
                'TomFormStringDropdown below — both write the same '
                'observable, so type-swap is free of lost state.'),
            const _Bullet('Drag the splitter to cross every breakpoint '
                'without resizing the window.'),
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

  Widget _activeBandBadge(BuildContext context, double width) {
    String band;
    if (width >= 1600) {
      band = '≥ 1600 — bordered preset, deep-blue Georgia';
    } else if (width >= 1200) {
      band = '≥ 1200 — material3 + 3 px outline, teal Georgia';
    } else if (width >= 800) {
      band = '≥ 800 — smaller-font material3, purple Roboto';
    } else if (width >= 400) {
      band = '≥ 400 — compact + 1 px outline, indigo monospace';
    } else {
      band = '< 400 — compact fallback, orange monospace';
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

  Widget _buildInfoColumn(BuildContext context) {
    return InfoPanel(
      title: 'Breakpoint cheat sheet',
      children: [
        _row(context, '≥ 1600', 'bordered + blue Georgia'),
        _row(context, '≥ 1200', 'material3 3 px + teal Georgia'),
        _row(context, '≥ 800', 'smaller fonts + purple Roboto'),
        _row(context, '≥ 400', 'compact 1 px + indigo monospace'),
        _row(context, '<  400', 'compact + orange monospace'),
        const InfoPanelHeading('Layout swaps'),
        _row(context, '<  800', 'classification row splits 2+2'),
        _row(context, '<  400', 'classification row splits 1+1+1+1'),
        _row(context, '< 1000', 'lead & reviewer subforms stack'),
        _row(context, '< 1000', 'priority Segmented → Dropdown swap'),
      ],
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(k,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      )),
            ),
            Expanded(
              child:
                  Text(v, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}

// ===========================================================================
// Shared complex form pane — reused verbatim by Demo H so the auth overlay
// exercises the exact same breakpoint scaffolding.
// ===========================================================================

Widget buildComplexFormPane({
  required BuildContext context,
  required ProjectBriefForm form,
  required ProjectBrief state,
}) {
  // --- Style presets -------------------------------------------------------
  const border1 = OutlineInputBorder(borderSide: BorderSide(width: 1));
  const border3 = OutlineInputBorder(borderSide: BorderSide(width: 3));
  final errorBorder1 = OutlineInputBorder(
    borderSide: BorderSide(width: 1, color: Colors.red.shade700),
  );
  final errorBorder3 = OutlineInputBorder(
    borderSide: BorderSide(width: 3, color: Colors.red.shade700),
  );

  final compact1px = TomFormStyle.compact.copyWith(
    defaults: TomFormStyle.compact.defaults.copyWith(
      fieldBorder: border1,
      focusedBorder: border1,
      errorBorder: errorBorder1,
    ),
  );
  final smallerFonts = TomFormStyle.material3.copyWith(
    defaults: TomFormStyle.material3.defaults.copyWith(
      labelStyle: const TextStyle(fontSize: 11),
      inputStyle: const TextStyle(fontSize: 12),
      hintStyle: const TextStyle(fontSize: 11),
      descriptionStyle: const TextStyle(fontSize: 10),
      fieldBorder: border1,
      focusedBorder: border1,
    ),
  );
  final normal3px = TomFormStyle.material3.copyWith(
    defaults: TomFormStyle.material3.defaults.copyWith(
      fieldBorder: border3,
      focusedBorder: border3,
      errorBorder: errorBorder3,
    ),
  );
  final bordered = TomFormStyle.bordered;

  // --- Theme presets -------------------------------------------------------
  ThemeData mk(Color seed, {String? fontFamily}) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        fontFamily: fontFamily,
      );
  final orangeMono = mk(Colors.deepOrange, fontFamily: 'monospace');
  final indigoMono = mk(Colors.indigo, fontFamily: 'monospace');
  final purpleRoboto = mk(Colors.purple);
  final tealSerif = mk(Colors.teal, fontFamily: 'Georgia');
  final blueSerif = mk(Colors.blue, fontFamily: 'Georgia');

  return TomFormStyleScope(
    style: compact1px,
    styleBpOverrides: [
      (400, compact1px),
      (800, smallerFonts),
      (1200, normal3px),
      (1600, bordered),
    ],
    theme: orangeMono,
    themeBpOverrides: [
      (400, indigoMono),
      (800, purpleRoboto),
      (1200, tealSerif),
      (1600, blueSerif),
    ],
    child: _ComplexFormBody(form: form, state: state),
  );
}

class _ComplexFormBody extends StatefulWidget {
  final ProjectBriefForm form;
  final ProjectBrief state;
  const _ComplexFormBody({required this.form, required this.state});

  @override
  State<_ComplexFormBody> createState() => _ComplexFormBodyState();
}

class _ComplexFormBodyState extends State<_ComplexFormBody> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final stackSubforms = width < 1000;
        final prioritySegmented = width >= 1000;

        // ---- Identity row (code, title, budget) --------------------
        final identity = TomAclBuilder(
          id: 'identity',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .setAclDefaultAppendGap(
              16,
              const [(400, 4), (800, 8), (1200, 16), (1600, 24)],
            )
            .append((p) => p.code.widget)
            .append((p) => p.title.widget, dist: 16)
            .addRowBreakpoint(atWidth: 800)
            .append((p) => p.budget.widget, dist: 16);

        // ---- Classification row with width-dependent splits ---------
        final classification = TomAclBuilder(
          id: 'classification',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .setAclDefaultAppendGap(
              12,
              const [(400, 4), (800, 8), (1200, 12), (1600, 20)],
            )
            .append((p) => p.category.widget)
            .append((p) => p.status.widget)
            .addRowBreakpoint(atWidth: 800)
            .append((_) => _priorityWidget(prioritySegmented))
            .append((p) => p.phase.widget)
            .addRowBreakpoint(atWidth: 400);

        // ---- Scope row (hours, deadline, location) ------------------
        final scope = TomAclBuilder(
          id: 'scope',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .setAclDefaultAppendGap(
              12,
              const [(400, 4), (800, 8), (1200, 12), (1600, 20)],
            )
            .setAclDefaultRowHeight(
              null,
              const [(400, 72), (800, null), (1200, null)],
            )
            .append((p) => p.hoursEstimate.widget)
            .append((p) => p.deadline.widget)
            .addRowBreakpoint(atWidth: 800)
            .append((p) => p.location.widget);

        // ---- Classic field row (still Phase-1 API) -------------------
        final classic = TomAclBuilder(
          id: 'classic',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .setAclDefaultAppendGap(12)
            .append((p) => p.internalRef.widget)
            .append((p) => p.contactEmail.widget, dist: 16)
            .addRowBreakpoint(atWidth: 800);

        // ---- Summary / description / risk (full-width multi-line) ---
        final summary = TomAclBuilder(
          id: 'summary',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .append((p) => p.summary.widget);
        final description = TomAclBuilder(
          id: 'description',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .append((p) => p.description.widget);
        final riskNotes = TomAclBuilder(
          id: 'riskNotes',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .append((p) => p.riskNotes.widget);

        // ---- Nested Person subforms — side-by-side or stacked -------
        final lead = _personSubform(context, 'Lead', widget.form.lead);
        final reviewer =
            _personSubform(context, 'Reviewer', widget.form.reviewer);
        final people = stackSubforms
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  lead,
                  const SizedBox(height: 12),
                  reviewer,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: lead),
                  const SizedBox(width: 16),
                  Expanded(child: reviewer),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, 'Identity'),
            identity.build(context),
            _sectionTitle(context, 'Classification'),
            classification.build(context),
            _sectionTitle(context, 'Scope'),
            scope.build(context),
            _sectionTitle(context, 'Classic-field pair'),
            classic.build(context),
            _sectionTitle(context, 'Summary'),
            summary.build(context),
            _sectionTitle(context, 'People'),
            people,
            _sectionTitle(context, 'Description'),
            description.build(context),
            _sectionTitle(context, 'Risk notes'),
            riskNotes.build(context),
            const SizedBox(height: 12),
            _inlineExtras(context),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );

  Widget _priorityWidget(bool segmented) {
    // When wide → render priority as an inline SegmentedButton driving the
    // same field observable. When narrow → fall back to the
    // TomFormStringDropdown's own widget. Same observable in both cases
    // so swapping doesn't drop state.
    if (!segmented) return widget.form.priority.widget;
    return TomMultiObservableBuilder(
      observables: [widget.form.priority],
      builder: (context) {
        final value = widget.form.priority.get();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'low', label: Text('low')),
              ButtonSegment(value: 'medium', label: Text('medium')),
              ButtonSegment(value: 'high', label: Text('high')),
              ButtonSegment(value: 'critical', label: Text('critical')),
            ],
            selected: {value.isEmpty ? 'medium' : value},
            onSelectionChanged: (s) =>
                widget.form.priority.setValue(s.first),
            showSelectedIcon: false,
          ),
        );
      },
    );
  }

  Widget _personSubform(
      BuildContext context, String label, PersonSubform sub) {
    final layout = TomAclBuilder(id: label.toLowerCase(), elementProvider: sub)
        .setAclExpandXDefault(true)
        .setAclDefaultAppendGap(
          12,
          const [(400, 4), (800, 8)],
        )
        .append((p) => p.firstName.widget)
        .append((p) => p.lastName.widget)
        .addRowBreakpoint(atWidth: 500)
        .append((p) => p.email.widget)
        .append((p) => p.phone.widget)
        .addRowBreakpoint(atWidth: 500)
        .append((p) => p.title.widget);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            layout.build(context),
          ],
        ),
      ),
    );
  }

  Widget _inlineExtras(BuildContext context) {
    // Phase 2 bool + tag observables live on the state directly (since
    // Phase 2 TomField implementations for these don't exist yet). The
    // bindings write through [state.*] so the real form's setValues still
    // captures them on save.
    final state = widget.state;
    return TomMultiObservableBuilder(
      observables: [
        state.isPublic,
        state.needsReview,
        state.notifySubscribers,
        state.tags,
      ],
      builder: (context) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Flags (Phase 2 bool stand-ins)',
                style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _boolSwitch(context, state.isPublic, 'Public'),
                _boolSwitch(context, state.needsReview, 'Needs review'),
                _boolSwitch(context, state.notifySubscribers,
                    'Notify subscribers'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tags (Phase 2 multi-select stand-in)',
                style: theme.textTheme.titleSmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in state.tags.toList())
                  InputChip(
                    label: Text(t.get()),
                    onDeleted: () => state.tags
                        .removeWhere((o) => o.get() == t.get()),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _boolSwitch(BuildContext context, TomBool flag, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: flag.get(),
          onChanged: (v) => flag | v,
        ),
        Text(label),
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
