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

  Future<void> _save() async {
    final ok = await _form.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Saved — phase2ProjectBriefState updated.'
          : 'Validation failed — check field errors.'),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Empties every string field in the form and its nested subforms.
  /// Dropdowns with required validators show their validation error after
  /// a clear — that's intended, it makes the `Save` button a live demo of
  /// validation gating the roundtrip.
  void _clear() {
    clearProjectBriefForm(_form);
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
        projectBriefActionBar(
          context: context,
          onClear: _clear,
          onSave: _save,
        ),
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
// Shared helpers — reused verbatim by Demo H.
// ===========================================================================

/// Empties every string field in a [ProjectBriefForm] and its two
/// [PersonSubform] children via `setValue('')`. Dropdowns accept the
/// empty string (they're `TomField<String>`); required-validator fields
/// will show an error state until the user re-enters a value — that's
/// the intended "cleared state" for this demo.
void clearProjectBriefForm(ProjectBriefForm form) {
  void clearForm(TomForm f) {
    for (final field in f.fields.values) {
      if (field is TomField<String>) field.setValue('');
    }
  }

  clearForm(form);
  clearForm(form.lead);
  clearForm(form.reviewer);
}

/// Action bar hosting `Clear` + `Save` used by Demo G and Demo H. Laid out
/// as a trailing row inside a [Card] so it sits above the form pane with
/// the same visual weight as the other meta-panels.
Widget projectBriefActionBar({
  required BuildContext context,
  required VoidCallback onClear,
  required VoidCallback onSave,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Shared complex form pane — reused verbatim by Demo H so the auth overlay
// exercises the exact same breakpoint scaffolding.
// ===========================================================================

// ---------------------------------------------------------------------------
// Style + theme presets — file-scope so the SAME instances are handed to
// TomFormStyleScope on every rebuild. If these were recreated per call,
// every Demo G rebuild would hand fresh ThemeData / style objects into
// the scope, and Flutter's InheritedWidget machinery would treat each
// one as a change — descendant TextFields and their FocusNodes would
// churn and typing would unfocus after each character.
// ---------------------------------------------------------------------------

/// Bordered preset with extra vertical content padding and a pinned
/// floating-label size. `withTheme()` fills [TomFieldStyle.labelStyle]
/// from the theme's `bodyMedium`, which in the ≥1600 band is 18 px
/// serif. A floating label that big overflows the field-top contentPadding
/// and the top half is clipped by the container — the border line then
/// visually bisects the characters. Pinning `labelStyle` to ~13 px keeps
/// the floating label compact enough to fit entirely above the border,
/// and bumping vertical contentPadding to 14 px gives the label comfortable
/// breathing room over the 1 px outline. `withColorOrInherit` in
/// [TomFormStyle.withTheme] still preserves the `current` (our pinned
/// style) because it's not identical to the null origin.
final _borderedRoomy = TomFormStyle.bordered.copyWith(
  defaults: TomFormStyle.bordered.defaults.copyWith(
    fieldContentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    labelStyle: const TextStyle(fontSize: 13, inherit: true),
  ),
);

/// Material preset with a heavier bottom border (5 px enabled → 7 px on
/// focus) to make the middle band visually distinct from the bordered and
/// compact neighbours without straying away from the material style.
///
/// `borderRadius: BorderRadius.zero` is explicit here: Flutter's default
/// `UnderlineInputBorder` rounds its top-left / top-right corners at 4 px,
/// which is invisible at 1–2 px widths but renders as upward-bending
/// "cut-off" ends at 5–7 px. A zero radius keeps the thick baseline flat.
final _materialHeavy = TomFormStyle.material3.copyWith(
  defaults: TomFormStyle.material3.defaults.copyWith(
    fieldBorder: const UnderlineInputBorder(
      borderSide: BorderSide(width: 5),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(width: 7),
      borderRadius: BorderRadius.zero,
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: BorderSide(width: 5, color: Colors.red.shade700),
      borderRadius: BorderRadius.zero,
    ),
  ),
);

ThemeData _mkTheme({
  required Color seed,
  String? fontFamily,
  double bodySize = 14,
}) {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    useMaterial3: true,
    fontFamily: fontFamily,
  );
  final cs = base.colorScheme;
  TextStyle ink(TextStyle? s, double size) =>
      (s ?? const TextStyle()).copyWith(fontSize: size, color: cs.primary);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodySmall: ink(base.textTheme.bodySmall, bodySize - 2),
      bodyMedium: ink(base.textTheme.bodyMedium, bodySize),
      bodyLarge: ink(base.textTheme.bodyLarge, bodySize + 2),
      labelSmall: ink(base.textTheme.labelSmall, bodySize - 3),
      labelMedium: ink(base.textTheme.labelMedium, bodySize - 2),
      labelLarge: ink(base.textTheme.labelLarge, bodySize - 1),
      titleSmall: ink(base.textTheme.titleSmall, bodySize + 1),
      titleMedium: ink(base.textTheme.titleMedium, bodySize + 3),
      titleLarge: ink(base.textTheme.titleLarge, bodySize + 6),
    ),
  );
}

final _orangeMonoXs =
    _mkTheme(seed: Colors.deepOrange, fontFamily: 'monospace', bodySize: 11);
final _indigoMonoS =
    _mkTheme(seed: Colors.indigo, fontFamily: 'monospace', bodySize: 12);
final _purpleSans = _mkTheme(seed: Colors.purple, bodySize: 14);
final _tealSerifL =
    _mkTheme(seed: Colors.teal, fontFamily: 'serif', bodySize: 16);
final _blueSerifXl =
    _mkTheme(seed: Colors.blue, fontFamily: 'serif', bodySize: 18);

final _styleBpOverrides = <(double, TomFormStyle)>[
  (800, _materialHeavy),
  (1600, _borderedRoomy),
];

final _themeBpOverrides = <(double, ThemeData)>[
  (400, _indigoMonoS),
  (800, _purpleSans),
  (1200, _tealSerifL),
  (1600, _blueSerifXl),
];

Widget buildComplexFormPane({
  required BuildContext context,
  required ProjectBriefForm form,
  required ProjectBrief state,
}) {
  // Only the three shipped TomFormStyle presets — bordered / material /
  // compact — are used:
  //
  //   ≥ 1600 → bordered               (default at widest)
  //   ≥  800 → material3 heavy (5/7)  (two theme-varying bands share this)
  //   <  800 → compact
  //
  // The material band spans 800..1599 so the *theme* swaps between 1200
  // and 800 without changing the style preset.
  return TomFormStyleScope(
    style: TomFormStyle.compact,
    styleBpOverrides: _styleBpOverrides,
    theme: _orangeMonoXs,
    themeBpOverrides: _themeBpOverrides,
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
            .addRowBreakpoint(atWidth: 900)
            .append((p) => p.budget.widget, dist: 16)
            .addRowBreakpoint(atWidth: 500);

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
            .addRowBreakpoint(atWidth: 1400)
            .append((_) => _priorityWidget(prioritySegmented))
            .append((p) => p.phase.widget)
            .addRowBreakpoint(atWidth: 700)
            .addRowBreakpoint(atWidth: 500);

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
            .addRowBreakpoint(atWidth: 900)
            .append((p) => p.location.widget)
            .addRowBreakpoint(atWidth: 500);

        // ---- Classic field row (still Phase-1 API) -------------------
        final classic = TomAclBuilder(
          id: 'classic',
          elementProvider: widget.form,
        )
            .setAclExpandXDefault(true)
            .setAclDefaultAppendGap(12)
            .append((p) => p.internalRef.widget)
            .append((p) => p.contactEmail.widget, dist: 16)
            .addRowBreakpoint(atWidth: 900);

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
            _sectionCard(identity.build(context)),
            _sectionTitle(context, 'Classification'),
            _sectionCard(classification.build(context)),
            _sectionTitle(context, 'Scope'),
            _sectionCard(scope.build(context)),
            _sectionTitle(context, 'Classic-field pair'),
            _sectionCard(classic.build(context)),
            _sectionTitle(context, 'Summary'),
            _sectionCard(summary.build(context)),
            _sectionTitle(context, 'People'),
            people,
            _sectionTitle(context, 'Description'),
            _sectionCard(description.build(context)),
            _sectionTitle(context, 'Risk notes'),
            _sectionCard(riskNotes.build(context)),
            const SizedBox(height: 12),
            _sectionCard(_inlineExtras(context)),
          ],
        );
      },
    );
  }

  /// Per-section Card. Cards resolve their background through `CardTheme`
  /// (theme.cardTheme), so the palette swap lands on the field containers
  /// without the outer form pane having to read Theme.of on every build
  /// — which was causing a full rebuild cascade on every typed character
  /// and killing field focus.
  Widget _sectionCard(Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    // Colour-filled title block so the theme palette + font family +
    // textTheme scale are all unmistakable in the non-Card sections too.
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontFamily: theme.textTheme.titleSmall?.fontFamily,
          ),
        ),
      ),
    );
  }

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
