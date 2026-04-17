import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/company_forms.dart';
import '../state/application_state.dart';

// ---------------------------------------------------------------------------
// Demo 9: Preset Showcase
// ---------------------------------------------------------------------------

/// Side-by-side proof of visual consistency between form fields and the
/// surrounding Material theme.
///
/// Rows  = every currently-implemented field type (string input, dropdown).
/// Cols  = the three presets (`material3`, `compact`, `bordered`).
/// Toggle flips `withTheme(Theme.of(context))` on/off to prove the theme
/// derivation is active.
///
/// Each cell hosts its own `TomFormStyleScope`, all backed by a single
/// shared form instance so typing in any cell updates the value everywhere
/// — the visual delta is style-only.
class Demo9PresetShowcase extends StatefulWidget {
  const Demo9PresetShowcase({super.key});

  @override
  State<Demo9PresetShowcase> createState() => _Demo9PresetShowcaseState();
}

class _Demo9PresetShowcaseState extends State<Demo9PresetShowcase> {
  late final CompanyBasicInfoForm _form;

  bool _applyTheme = false;

  /// Local themes for the preset grid. Each one changes color, font family,
  /// and font size — withTheme picks up all of it. Kept deliberately distinct
  /// from the app's blue theme so the swap is obvious. Pick via the toggle.
  static final _themeChoices = <({String label, ThemeData data})>[
    (
      label: 'Purple / Serif / large',
      data: _buildTheme(
        seed: Colors.deepPurple,
        fontFamily: 'serif',
        bodySize: 16,
        labelSize: 15,
      ),
    ),
    (
      label: 'Teal / Mono / small',
      data: _buildTheme(
        seed: Colors.teal,
        fontFamily: 'monospace',
        bodySize: 12,
        labelSize: 11,
      ),
    ),
    (
      label: 'Orange / Sans / medium',
      data: _buildTheme(
        seed: Colors.orange,
        fontFamily: 'sans-serif',
        bodySize: 14,
        labelSize: 13,
      ),
    ),
    (
      label: 'Crimson / Serif / bold',
      data: _buildTheme(
        seed: Colors.red,
        fontFamily: 'serif',
        bodySize: 15,
        labelSize: 14,
        bodyWeight: FontWeight.w700,
      ),
    ),
  ];
  int _themeIndex = 0;

  ThemeData get _localTheme => _themeChoices[_themeIndex].data;

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

  /// Picked theme — this is what `withTheme` bakes into the TomFormStyle.
  TomFormStyle _style(TomFormStyle preset) {
    return _applyTheme ? preset.withTheme(_localTheme) : preset;
  }

  /// Neutral grey render theme the grid lives under. Kept deliberately plain
  /// so the only colorful element comes from `withTheme`'s baked-in styles.
  static final _neutralTheme = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF666666),
      onSurface: Color(0xFF333333),
      outline: Color(0xFFBBBBBB),
    ),
    useMaterial3: true,
    fontFamily: 'sans-serif',
  );

  @override
  Widget build(BuildContext context) {
    const presets = <({String name, TomFormStyle Function() build})>[
      (name: 'material3', build: _material3),
      (name: 'compact', build: _compact),
      (name: 'bordered', build: _bordered),
    ];

    final fieldRows = <({String label, Widget Function() build})>[
      (label: 'TomFormStringInput', build: () => _form.name.widget),
      (label: 'TomFormStringDropdown', build: () => _form.industry.widget),
    ];

    return DemoScaffold(
      title: 'Demo 9: Preset Showcase',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildReferenceCard(context),
            const SizedBox(height: 16),
            _buildControls(context),
            const SizedBox(height: 16),
            // The grid always renders under a neutral grey "render" theme.
            // When the toggle is OFF, the presets have null styles and the
            // fields inherit the grey. When it's ON, `withTheme(pickedTheme)`
            // bakes the picked theme's colors and fonts into the TomFormStyle
            // itself — so the fields now show the picked theme even though
            // the ambient Material theme is still grey.
            Theme(
              data: _neutralTheme,
              child: Builder(
                builder: (ctx) => Container(
                  color: Theme.of(ctx).colorScheme.surface,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderRow(ctx, presets),
                      const Divider(height: 8),
                      for (final fieldRow in fieldRows) ...[
                        _buildFieldRow(ctx, fieldRow, presets),
                        const Divider(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header and cells ─────────────────────────────────────────────────────

  Widget _buildHeaderRow(
    BuildContext context,
    List<({String name, TomFormStyle Function() build})> presets,
  ) {
    return Row(
      children: [
        const SizedBox(width: 180),
        for (final preset in presets)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                preset.name,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldRow(
    BuildContext context,
    ({String label, Widget Function() build}) fieldRow,
    List<({String name, TomFormStyle Function() build})> presets,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(
              fieldRow.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        for (final preset in presets)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TomFormStyleScope(
                style: _style(preset.build()),
                child: fieldRow.build(),
              ),
            ),
          ),
      ],
    );
  }

  // ── Controls ─────────────────────────────────────────────────────────────

  Widget _buildControls(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: _applyTheme,
                  onChanged: (v) => setState(() => _applyTheme = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _applyTheme
                        ? 'withTheme(picked) is ON — the picked theme is '
                            'baked into each TomFormStyle. The grid renders '
                            'under a neutral grey Material theme, so any '
                            'color/font you see comes from withTheme.'
                        : 'withTheme is OFF — presets carry only their own '
                            'baked-in properties (label placement, gaps, '
                            'border variant). Colors and fonts fall back to '
                            'the grey render theme the grid lives under.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Local theme:',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < _themeChoices.length; i++)
                      ButtonSegment(
                        value: i,
                        label: Text(_themeChoices[i].label),
                      ),
                  ],
                  selected: {_themeIndex},
                  onSelectionChanged: (s) =>
                      setState(() => _themeIndex = s.first),
                ),
              ],
            ),
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
              'Preset reference',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const _Bullet(
              'material3 — the vanilla Material-3 defaults: label above, '
                  'standard gaps, no outline border.',
            ),
            const _Bullet(
              'compact — floating labels and tighter vertical gaps. '
                  'Good for dense forms.',
            ),
            const _Bullet(
              'bordered — floating labels on an outlined border with '
                  'error-border recolour and trailing error icon enabled.',
            ),
            const SizedBox(height: 6),
            const _Bullet(
              'withTheme(theme) snapshots the theme into the TomFormStyle. '
                  'Label/input: take bodyMedium as-is — the theme creator\'s '
                  'bodyMedium.color wins (null stays null so it inherits). '
                  'Hint: bodyMedium recoloured to cs.onSurfaceVariant. '
                  'Error: bodySmall + cs.error. Description: bodySmall + '
                  'cs.onSurfaceVariant. Backgrounds: surfaceContainer*.',
            ),
            const _Bullet(
              'In this demo the picked themes set bodyMedium.color to '
                  'cs.primary so you can actually see the theme accent on '
                  'labels and typed text. That\'s a demo choice — real apps '
                  'usually leave bodyMedium.color null so labels adopt the '
                  'standard onSurface text colour.',
            ),
            const _Bullet(
              'Border variant is preserved: null stays null, outlined stays '
                  'outlined — only the stroke color follows the theme. So '
                  'material3 and compact keep their underlined look; '
                  'bordered keeps its outlined look and only recolors.',
            ),
            const _Bullet(
              'The grid below lives under a neutral grey Material theme, so '
                  'any color/font difference between OFF and ON is the work '
                  'of withTheme alone.',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preset builders ────────────────────────────────────────────────────────

TomFormStyle _material3() => TomFormStyle.material3;
TomFormStyle _compact() => TomFormStyle.compact;
TomFormStyle _bordered() => TomFormStyle.bordered;

/// Builds a ThemeData with distinctive color, font family, and sizes so the
/// `withTheme` swap is visually unmistakable.
///
/// Key choices that make this demo readable:
///   - `bodyMedium.color` is set to `scheme.primary` so labels and typed
///     text pick up the theme's accent color (purple, teal, orange…).
///     Framework convention is to let `bodyMedium.color` stay null and
///     inherit onSurface; we override here deliberately so the demo SHOWS
///     the colour — in a real app you'd probably not want purple labels.
///   - `bodySmall.color` is left null so hint/description fall back to
///     `cs.onSurfaceVariant` (the muted token) applied by `withTheme`.
ThemeData _buildTheme({
  required Color seed,
  required String fontFamily,
  required double bodySize,
  required double labelSize,
  FontWeight bodyWeight = FontWeight.w400,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        fontSize: bodySize,
        fontFamily: fontFamily,
        fontWeight: bodyWeight,
        color: scheme.primary,
      ),
      bodySmall: TextStyle(fontSize: bodySize - 2, fontFamily: fontFamily),
      labelLarge: TextStyle(
        fontSize: labelSize,
        fontFamily: fontFamily,
        fontWeight: bodyWeight,
        color: scheme.primary,
      ),
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
