import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 10: Central JSON-Driven Form Style
// ---------------------------------------------------------------------------

/// Proves that a single [TomFormStyleScope] at the root drives the entire
/// form's visual appearance from `demo_resources.json`, with:
///
///   1. **Flutter theme selector** — wraps the form pane in Flutter's standard
///      `Theme(data: ...)` widget. The scope's automatic `withTheme()` call
///      picks up the ambient theme so all `cs.*` tokens in the JSON resolve
///      against the selected palette. No `theme` / `themeSpec` parameters are
///      set on the scope — it simply reads `Theme.of(context)`.
///
///   2. **Drag-to-resize pane** — crosses `TomBreakpoint.mobile/.tablet/
///      .desktop` to show the `@bp.{name}.*` JSON overrides activating,
///      including `@bp.tablet.theme` and `@bp.desktop.theme` which substitute
///      the Material theme at those breakpoints regardless of the selector.
///
///   3. **Zero Dart-level style** — no colours, font sizes, or placements are
///      hard-coded below the scope. Edit `demo_resources.json` and hot-reload.
class Demo10CentralJsonStyle extends StatefulWidget {
  const Demo10CentralJsonStyle({super.key});

  @override
  State<Demo10CentralJsonStyle> createState() => _Demo10CentralJsonStyleState();
}

// ── Theme catalogue ────────────────────────────────────────────────────────

typedef _ThemeEntry = ({String label, ThemeData data});

List<_ThemeEntry> _buildThemes() => [
      (
        label: 'Default (M3 blue)',
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
          useMaterial3: true,
        ),
      ),
      (
        label: 'Purple',
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
          useMaterial3: true,
        ),
      ),
      (
        label: 'Indigo',
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
          useMaterial3: true,
        ),
      ),
      (
        label: 'Teal',
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
          useMaterial3: true,
        ),
      ),
      (
        label: 'Crimson',
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC62828)),
          useMaterial3: true,
        ),
      ),
    ];

// ── State ──────────────────────────────────────────────────────────────────

class _Demo10CentralJsonStyleState extends State<Demo10CentralJsonStyle> {
  late final CompanyBasicInfoForm _form;
  final _themes = _buildThemes();

  int _selectedThemeIndex = 0;
  double _widthFraction = 1.0;

  ThemeData get _selectedTheme => _themes[_selectedThemeIndex].data;

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

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo 10: Central JSON-Driven Style',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final paneWidth =
              (totalWidth * _widthFraction).clamp(200.0, totalWidth);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReferenceCard(context),
                const SizedBox(height: 16),
                _buildThemeSelector(context),
                const SizedBox(height: 8),
                _buildSplitter(context, totalWidth, paneWidth),
                const SizedBox(height: 8),
                _buildBreakpointBadges(paneWidth),
                const SizedBox(height: 16),
                // Wrap the form pane in Flutter's Theme widget — the
                // TomFormStyleScope below has no explicit theme params.
                // Its automatic withTheme() reads Theme.of(context) here,
                // so the selected palette flows in through Flutter's own
                // mechanism. @bp.tablet/desktop.theme in JSON overrides at
                // those widths regardless of the selector.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Theme(
                    data: _selectedTheme,
                    child: SizedBox(
                      width: paneWidth,
                      child: TomFormStyleScope(
                        tomId: 'demo10Form',
                        style: const TomFormStyle(),
                        child: Builder(builder: (ctx) => _buildForm(ctx)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildJsonPreview(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    // Show the resolved primary colour so the user can see it responding.
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: cs.primaryContainer,
          child: Text(
            'Active cs.primary: ${_hexOf(cs.primary)}  '
            '(label & input text follow this token)',
            style: TextStyle(
              fontSize: 11,
              color: cs.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _buildFormFields(context),
      ],
    );
  }

  static String _hexOf(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  Widget _buildFormFields(BuildContext context) {
    return TomAclBuilder(
      id: 'demo10Layout',
      elementProvider: _form,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
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

  // ── Theme selector ────────────────────────────────────────────────────────

  Widget _buildThemeSelector(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flutter theme', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _themes.length; i++)
                  _ThemeChip(
                    label: _themes[i].label,
                    primaryColor: _themes[i].data.colorScheme.primary,
                    selected: i == _selectedThemeIndex,
                    onTap: () => setState(() => _selectedThemeIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Wraps the form pane in Flutter\'s Theme(data: …) widget. '
              'TomFormStyleScope has no explicit theme params — its automatic '
              'withTheme() reads Theme.of(context), so all cs.* colour tokens '
              'in the JSON resolve against the palette you pick here. '
              '@bp.tablet/desktop.theme in the JSON overrides this at those '
              'breakpoints regardless of the selection.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ── Splitter ──────────────────────────────────────────────────────────────

  Widget _buildSplitter(
      BuildContext context, double totalWidth, double paneWidth) {
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
              min: 200.0 / totalWidth.clamp(201.0, double.infinity),
              max: 1.0,
              onChanged: (v) => setState(() => _widthFraction = v),
            ),
            Text(
              'Cross TomBreakpoint.mobile (${TomBreakpoint.mobile.toStringAsFixed(0)}), '
              '.tablet (${TomBreakpoint.tablet.toStringAsFixed(0)}), '
              '.desktop (${TomBreakpoint.desktop.toStringAsFixed(0)}) — '
              'the JSON @bp blocks activate. '
              '@bp.tablet/desktop also swap the theme seed (teal / orange), '
              'overriding the Flutter selector above.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active-breakpoint badges ──────────────────────────────────────────────

  Widget _buildBreakpointBadges(double width) {
    String active;
    if (width >= TomBreakpoint.desktop) {
      active = '≥ desktop — padding 16×20, body size 17. '
          'Theme from Flutter selector (only typography changes at bp).';
    } else if (width >= TomBreakpoint.tablet) {
      active = '≥ tablet — label above, body size 15, weights bumped. '
          'Theme from Flutter selector (only typography changes at bp).';
    } else if (width >= TomBreakpoint.mobile) {
      active = '≥ mobile — padding 14×18, font size 15. Theme from '
          'Flutter selector.';
    } else {
      active = '< mobile (base) — font size 14. Theme from Flutter selector.';
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Active block → $active',
            style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }

  // ── Reference card ────────────────────────────────────────────────────────

  Widget _buildReferenceCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What this demo shows',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            const _Bullet(
              'style: TomFormStyle() is the fallback base — it supplies '
              'canonical defaults for any property absent from the JSON.',
            ),
            const _Bullet(
              'tomId: "demo10Form" triggers the resource overlay, which reads '
              'every style property from demo_resources.json including '
              'cs.* colour tokens resolved against the active ColorScheme. '
              'labelPlacement is "floating" so labels live inside the box '
              'and visibly change colour (cs.primary) when you pick a theme.',
            ),
            const _Bullet(
              'TomFormStyleScope has no explicit theme params. Its automatic '
              'withTheme(Theme.of(context)) fills in origin-default properties '
              'from the Flutter theme set by the selector above.',
            ),
            const _Bullet(
              '@bp.{name} blocks in JSON override specific properties when '
              'the pane crosses a breakpoint. @bp.tablet.theme and '
              '@bp.desktop.theme only carry typography changes (bodySize, '
              'weights) — NOT a seed — so the Flutter selector above always '
              'controls the colour scheme. Add "seed": "#…" to an @bp theme '
              'if you want that breakpoint to override the selector too.',
            ),
            const _Bullet(
              'No Dart-level style calls anywhere below the scope. Edit '
              'demo_resources.json and hot-reload to redesign the form.',
            ),
          ],
        ),
      ),
    );
  }

  // ── JSON preview ──────────────────────────────────────────────────────────

  Widget _buildJsonPreview(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('demo_resources.json excerpt',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            const SelectableText(
              _jsonExcerpt,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip helper ────────────────────────────────────────────────────────────

class _ThemeChip extends StatelessWidget {
  final String label;
  final Color primaryColor;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.primaryColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? primaryColor
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white54 : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? ThemeData.estimateBrightnessForColor(primaryColor) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black
                        : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bullet helper ──────────────────────────────────────────────────────────

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

// ── JSON excerpt ───────────────────────────────────────────────────────────

const _jsonExcerpt = '''
// No base "theme" block here — the scope's withTheme() reads
// Theme.of(context) which is set by the selector above.
// Floating labels (inside the box) make cs.* colour changes visible
// without needing to focus a field.
"demo10Form": {
  "labelPlacement":   "floating",
  "fieldBorder":      { "kind": "outline", "width": 1, "color": "cs.outline" },
  "focusedBorder":    { "kind": "outline", "width": 2, "color": "cs.primary" },
  "errorBorder":      { "kind": "outline", "width": 2, "color": "cs.error"   },
  "labelStyle":       { "fontSize": 13, "fontWeight": "w500", "color": "cs.primary" },
  // cs.primary = theme accent — visible in typed text.
  "inputStyle":       { "fontSize": 14, "color": "cs.primary" },
  "hintFontWeight":   "w400",
  "hintOpacity":      0.6,

  "@bp": {
    // bps only change typography — no seed → selector controls colour.
    // labelPlacement stays "floating" at every bp so the anatomy's widget
    // tree structure stays stable. Changing labelPlacement between bps
    // triggers an anatomy restructure (floating vs inline uses different
    // Column vs Row layouts), which re-mounts the field and briefly flashes
    // the hint while async items reload.
    "mobile":  { "inputStyle": { "fontSize": 15 } },
    "tablet":  { "labelStyle": { "fontSize": 15, "fontWeight": "w600" },
                 "theme": { "bodySize": 15 } },
    "desktop": { "labelStyle": { "fontSize": 16, "fontWeight": "w600" },
                 "theme": { "bodySize": 17 } }
  }
}
''';
