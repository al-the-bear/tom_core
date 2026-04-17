import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../forms/customer_form.dart';
import '../panels/info_panel.dart';
import '../state/phase1_state.dart';

// ---------------------------------------------------------------------------
// Demo C — Nested Forms & Theming (Phase 1)
// ---------------------------------------------------------------------------

/// Two-column layout: nested CustomerForm (fullName / email / phone /
/// customerTier / notes plus billing + shipping AddressForms) on the left;
/// theming controls and form-inspection panel on the right.
///
/// Covers every §24b Demo C feature:
///
///   * Nested forms — `customer.billing.*`, `customer.shipping.*`. Form tree
///     mirrors the [CustomerProfile] state tree exactly.
///   * Dirty tracking across the tree — dirty flags aggregate via a helper.
///   * `bind()` / `save()` / `discard()` fan out to each nested form.
///   * `TomFormStyle` live switching — label placement, error placement,
///     required indicators (label/hint/description), spacing, hint tuning,
///     preset buttons (material3/compact/bordered), and `withTheme` toggle.
///   * Per-section styling — billing and shipping each sit inside their
///     own nested `TomFormStyleScope` with different base presets.
///   * `styleBpOverrides` — shipping's scope swaps to `compact` at tablet
///     width and `bordered` at desktop width without touching the tree.
///   * Classic ↔ new coexistence — `notes` renders via
///     `TomFormStringInputClassic`, inside the same outer form as the new
///     `TomFormStringInput` fields.
///   * Form inspection panel — values as JSON, dirty fields, `initialSnapshot`
///     vs current diff, fields with errors, and aggregate isDirty/isValid.
class DemoCNestedTheming extends StatefulWidget {
  const DemoCNestedTheming({super.key});

  @override
  State<DemoCNestedTheming> createState() => _DemoCNestedThemingState();
}

class _DemoCNestedThemingState extends State<DemoCNestedTheming> {
  late final CustomerForm _form;

  // --- Theming state ---------------------------------------------------------
  _Preset _preset = _Preset.material3;
  bool _withTheme = false;

  LabelPlacement _labelPlacement = LabelPlacement.above;
  ErrorPlacement _errorPlacement = ErrorPlacement.below;
  RequiredIndicator _requiredLabel = RequiredIndicator.asterisk;
  RequiredIndicator _requiredHint = RequiredIndicator.none;
  RequiredIndicator _requiredDescription = RequiredIndicator.none;

  double _labelFieldGap = 4;
  double _errorFieldGap = 4;
  double _borderRadius = 8;
  int _hintWeight = 400;
  double _hintOpacity = 0.7;

  @override
  void initState() {
    super.initState();
    _form = TomScope.withScope('demoC', () => CustomerForm());
    _bindAll();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  // --- Nested-tree lifecycle helpers ----------------------------------------

  void _bindAll() {
    _form.bind(phase1CustomerState);
    _form.billing.bind(phase1CustomerState.billing);
    _form.shipping.bind(phase1CustomerState.shipping);
  }

  void _discardAll() {
    _form.discard();
    _form.billing.discard();
    _form.shipping.discard();
    setState(() {});
  }

  Future<void> _saveAll() async {
    final ok = await Future.wait([
      _form.save(),
      _form.billing.save(),
      _form.shipping.save(),
    ]).then((r) => r.every((e) => e));
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(ok ? 'Saved nested tree.' : 'Save failed (validation).'),
    ));
  }

  bool get _aggregateDirty =>
      _form.isDirty || _form.billing.isDirty || _form.shipping.isDirty;

  bool get _aggregateValid =>
      _form.isValid && _form.billing.isValid && _form.shipping.isValid;

  // --- Style resolution -----------------------------------------------------

  TomFormStyle _basePresetStyle() => switch (_preset) {
        _Preset.material3 => TomFormStyle.material3,
        _Preset.compact => TomFormStyle.compact,
        _Preset.bordered => TomFormStyle.bordered,
      };

  TomFormStyle _outerStyle(BuildContext context) {
    final base = _basePresetStyle();
    final withOverrides = base.copyWith(
      defaults: base.defaults.copyWith(
        labelPlacement: _labelPlacement,
        errorPlacement: _errorPlacement,
        requiredIndicator: _requiredLabel,
        requiredIndicatorOnHint: _requiredHint,
        requiredIndicatorOnDescription: _requiredDescription,
        labelFieldGap: _labelFieldGap,
        errorFieldGap: _errorFieldGap,
        borderRadius: _borderRadius,
        hintFontWeight: FontWeight.values.firstWhere(
          (w) => w.value == _hintWeight,
          orElse: () => FontWeight.w400,
        ),
        hintOpacity: _hintOpacity,
      ),
    );
    return _withTheme ? withOverrides.withTheme(Theme.of(context)) : withOverrides;
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo C — Nested Forms & Theming',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final form = _buildFormColumn(context);
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

  Widget _buildFormColumn(BuildContext context) {
    final topLayout = TomAclBuilder(
      id: 'demoCTop',
      elementProvider: _form,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.fullName.widget)
        .newRow()
        .append((p) => p.email.widget)
        .append((p) => p.phone.widget, dist: 16)
        .newRow()
        .append((p) => p.customerTier.widget)
        .newRow()
        .append((p) => p.notes.widget)
        .build(context);

    final billingLayout = TomAclBuilder(
      id: 'demoCBilling',
      elementProvider: _form.billing,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.state.widget, dist: 16)
        .newRow()
        .append((p) => p.zipCode.widget)
        .append((p) => p.country.widget, dist: 16)
        .build(context);

    final shippingLayout = TomAclBuilder(
      id: 'demoCShipping',
      elementProvider: _form.shipping,
    )
        .setAclDefaultRowAlignment(AclRowCrossAlignment.top)
        .setAclExpandXDefault(true)
        .append((p) => p.street.widget)
        .newRow()
        .append((p) => p.city.widget)
        .append((p) => p.state.widget, dist: 16)
        .newRow()
        .append((p) => p.zipCode.widget)
        .append((p) => p.country.widget, dist: 16)
        .build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        TomFormStyleScope(
          style: _outerStyle(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topLayout,
              const SizedBox(height: 16),

              // Billing section — own scope with the `compact` preset so the
              // per-section styling is visible next to the outer form.
              _section(
                context,
                'Billing address (compact preset)',
                TomFormStyleScope(
                  style: TomFormStyle.compact,
                  child: billingLayout,
                ),
              ),
              const SizedBox(height: 12),

              // Shipping section — bordered base, but styleBpOverrides swap
              // to compact at tablet and back to bordered at desktop so the
              // breakpoint-driven swap is observable without touching the
              // widget tree.
              _section(
                context,
                'Shipping address (bordered + breakpoint overrides)',
                TomFormStyleScope(
                  style: TomFormStyle.bordered,
                  styleBpOverrides: [
                    (TomBreakpoint.tablet, TomFormStyle.compact),
                    (TomBreakpoint.desktop, TomFormStyle.bordered),
                  ],
                  child: shippingLayout,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionRow(context),
      ],
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
            const _Bullet(
                'Nested tree — customer → billing, customer → shipping — '
                'each nested form binds/saves/discards independently.'),
            const _Bullet(
                'Live theming panel on the right drives the outer form; '
                'the billing/shipping scopes override with their own presets '
                'to demonstrate per-section styling.'),
            const _Bullet('Shipping section adds styleBpOverrides — resize '
                'the window (or narrow the right pane) to cross the tablet '
                'and desktop breakpoints and watch the preset flip.'),
            const _Bullet(
                'The notes field is a TomFormStringInputClassic — old API '
                'rendering side-by-side with the spec-conforming fields.'),
            const _Bullet('Form inspection card on the right prints the '
                'live value map, the initial snapshot diff, and the dirty '
                'field list.'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: _discardAll,
          icon: const Icon(Icons.undo),
          label: const Text('Discard'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _saveAll,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  // --- Right-hand columns ---------------------------------------------------

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Theming controls',
          children: [_buildThemingControls(context)],
        ),
        const SizedBox(height: 12),
        InfoPanel(
          title: 'Form inspection',
          children: [_buildInspection(context)],
        ),
      ],
    );
  }

  Widget _buildThemingControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const InfoPanelHeading('Preset + withTheme'),
        SegmentedButton<_Preset>(
          segments: const [
            ButtonSegment(value: _Preset.material3, label: Text('material3')),
            ButtonSegment(value: _Preset.compact, label: Text('compact')),
            ButtonSegment(value: _Preset.bordered, label: Text('bordered')),
          ],
          selected: {_preset},
          onSelectionChanged: (s) => setState(() => _preset = s.first),
          showSelectedIcon: false,
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('.withTheme(Theme.of(context))'),
          value: _withTheme,
          onChanged: (v) => setState(() => _withTheme = v),
        ),
        const InfoPanelHeading('Label placement'),
        _enumRow<LabelPlacement>(LabelPlacement.values, _labelPlacement,
            (v) => setState(() => _labelPlacement = v)),
        const InfoPanelHeading('Error placement'),
        _enumRow<ErrorPlacement>(ErrorPlacement.values, _errorPlacement,
            (v) => setState(() => _errorPlacement = v)),
        const InfoPanelHeading('Required — label'),
        _enumRow<RequiredIndicator>(RequiredIndicator.values, _requiredLabel,
            (v) => setState(() => _requiredLabel = v)),
        const InfoPanelHeading('Required — placeholder (hint)'),
        _enumRow<RequiredIndicator>(RequiredIndicator.values, _requiredHint,
            (v) => setState(() => _requiredHint = v)),
        const InfoPanelHeading('Required — description'),
        _enumRow<RequiredIndicator>(RequiredIndicator.values,
            _requiredDescription, (v) => setState(() => _requiredDescription = v)),
        const InfoPanelHeading('Spacing'),
        _sliderRow('labelFieldGap', _labelFieldGap, 0, 16,
            (v) => setState(() => _labelFieldGap = v)),
        _sliderRow('errorFieldGap', _errorFieldGap, 0, 16,
            (v) => setState(() => _errorFieldGap = v)),
        _sliderRow('borderRadius', _borderRadius, 0, 24,
            (v) => setState(() => _borderRadius = v)),
        const InfoPanelHeading('Hint tuning'),
        _sliderRow('hintFontWeight', _hintWeight.toDouble(), 100, 900,
            (v) => setState(() => _hintWeight = (v / 100).round() * 100),
            divisions: 8),
        _sliderRow('hintOpacity', _hintOpacity, 0, 1,
            (v) => setState(() => _hintOpacity = v),
            divisions: 10),
      ],
    );
  }

  Widget _enumRow<T>(List<T> values, T current, ValueChanged<T> onChanged) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text((v as Enum).name,
                style: Theme.of(context).textTheme.labelSmall),
            selected: v == current,
            visualDensity: VisualDensity.compact,
            onSelected: (sel) {
              if (sel) onChanged(v);
            },
          ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(
                label == 'hintOpacity' ? 2 : 0,
              ),
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // --- Inspection -----------------------------------------------------------

  Widget _buildInspection(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _form.changes,
        _form.billing.changes,
        _form.shipping.changes,
      ]),
      builder: (context, _) => _inspectionBody(context),
    );
  }

  Widget _inspectionBody(BuildContext context) {
    final values = {
      ..._form.getValues(),
      'billing': _form.billing.getValues(),
      'shipping': _form.shipping.getValues(),
    };

    final initial = {
      ...?_form.initialSnapshot,
      'billing': _form.billing.initialSnapshot ?? const {},
      'shipping': _form.shipping.initialSnapshot ?? const {},
    };

    final diff = _diff(initial, values);
    final dirtyFieldIds = <String>[
      ..._form.dirtyFields.map((f) => f.fieldId),
      ..._form.billing.dirtyFields.map((f) => 'billing.${f.fieldId}'),
      ..._form.shipping.dirtyFields.map((f) => 'shipping.${f.fieldId}'),
    ];
    final errorFieldIds = <String>[
      ..._form.fieldsWithErrors.map((f) => f.fieldId),
      ..._form.billing.fieldsWithErrors.map((f) => 'billing.${f.fieldId}'),
      ..._form.shipping.fieldsWithErrors.map((f) => 'shipping.${f.fieldId}'),
    ];

    final mono = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _stateChip(context, 'isDirty', _aggregateDirty),
            _stateChip(context, 'isValid', _aggregateValid),
          ],
        ),
        const SizedBox(height: 6),
        Text('Dirty: ${dirtyFieldIds.isEmpty ? "(none)" : dirtyFieldIds.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
        Text(
            'Errors: ${errorFieldIds.isEmpty ? "(none)" : errorFieldIds.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
        const InfoPanelHeading('getValues()'),
        SelectableText(const JsonEncoder.withIndent('  ').convert(values),
            style: mono),
        const InfoPanelHeading('Diff vs initialSnapshot'),
        if (diff.isEmpty)
          Text('(no changes)', style: Theme.of(context).textTheme.bodySmall)
        else
          SelectableText(
            diff.entries
                .map((e) => '${e.key}: ${e.value.$1} → ${e.value.$2}')
                .join('\n'),
            style: mono,
          ),
      ],
    );
  }

  Widget _stateChip(BuildContext context, String label, bool on) {
    final theme = Theme.of(context);
    final color = on ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text('$label: $on',
          style: theme.textTheme.labelSmall?.copyWith(color: color)),
    );
  }

  /// Flat diff between `initial` and `current`. Nested maps are keyed with
  /// dotted paths so the output lines read like `billing.city: "Paris" → "…"`.
  Map<String, (Object?, Object?)> _diff(
    Map<String, dynamic> initial,
    Map<String, dynamic> current, [
    String prefix = '',
  ]) {
    final out = <String, (Object?, Object?)>{};
    for (final key in {...initial.keys, ...current.keys}) {
      final a = initial[key];
      final b = current[key];
      final path = prefix.isEmpty ? key : '$prefix.$key';
      if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
        out.addAll(_diff(a, b, path));
      } else if (a != b) {
        out[path] = (a, b);
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

enum _Preset { material3, compact, bordered }

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
