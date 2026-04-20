import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';

// ---------------------------------------------------------------------------
// Demo E — Selection Variants (Phase 2 scaffold)
// ---------------------------------------------------------------------------

/// Two-column scaffold for the Phase 2 selection-variant demo described in
/// §Phase 2 of the spec:
///
///   * Five single-select / multi-select concrete implementations
///     (FilterChips / MultiCheckbox / Segmented / RadioGroup / ChoiceChips)
///     rendered side-by-side against the same [TomSelectableSource].
///   * A "bound values" inspector panel showing the observable writes each
///     variant produces, proving single-select flavours write back through
///     `TomString` and multi-select flavours through `TomList<TomString>`.
///   * A toggle that swaps the source between a full [StaticSelectableSource]
///     and a filtered subset so source observability is visible.
///
/// The concrete field widgets don't land until Phase 2 ships. Until then the
/// left column shows placeholder tiles so the navigation, layout, and
/// right-hand inspector scaffolding are exercisable today; each tile calls
/// out which spec-aligned widget is due to replace it.
class DemoESelectionVariants extends StatefulWidget {
  const DemoESelectionVariants({super.key});

  @override
  State<DemoESelectionVariants> createState() => _DemoESelectionVariantsState();
}

class _DemoESelectionVariantsState extends State<DemoESelectionVariants> {
  // Pre-created observables so the inspector panel on the right already
  // reflects the shape the widgets will write back into once Phase 2 fields
  // land: one `TomString` per single-select flavour, one
  // `TomList<TomString>` per multi-select flavour.
  final _filterChips = TomList<TomString>();
  final _multiCheckbox = TomList<TomString>();
  final _segmented = TomString('');
  final _radioGroup = TomString('');
  final _choiceChips = TomString('');

  bool _filteredSource = false;

  List<String> get _options => _filteredSource
      ? const ['tech', 'healthcare']
      : const [
          'tech',
          'finance',
          'healthcare',
          'manufacturing',
          'retail',
          'other',
        ];

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo E — Selection Variants',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _sourceToggleCard(context),
        const SizedBox(height: 12),
        _pendingVariant(
          context,
          'TomFormStringFilterChips',
          'Multi-select chips. Will write to TomList<TomString> (filterChips).',
        ),
        const SizedBox(height: 12),
        _pendingVariant(
          context,
          'TomFormStringMultiCheckbox',
          'Vertical multi-select. Will write to TomList<TomString> (multiCheckbox).',
        ),
        const SizedBox(height: 12),
        _pendingVariant(
          context,
          'TomFormStringSegmented',
          'Single-select segmented button. Will write to TomString (segmented).',
        ),
        const SizedBox(height: 12),
        _pendingVariant(
          context,
          'TomFormStringRadioGroup',
          'Single-select radio list. Will write to TomString (radioGroup).',
        ),
        const SizedBox(height: 12),
        _pendingVariant(
          context,
          'TomFormStringChoiceChips',
          'Single-select choice chips. Will write to TomString (choiceChips).',
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
            const _Bullet('Side-by-side presentation of every single- and '
                'multi-select flavour against one shared source.'),
            const _Bullet('Right-hand inspector shows the bound observable '
                'for each variant — confirms single-select writes through '
                'TomString and multi-select through TomList<TomString>.'),
            const _Bullet('Toggle the source between the full list and a '
                'filtered view to verify source observability.'),
            const _Bullet('Placeholder tiles until Phase 2 lands the '
                'concrete widgets — the scaffold already holds the right '
                'observables so swapping in the real widgets is a one-line '
                'edit per tile.'),
          ],
        ),
      ),
    );
  }

  Widget _sourceToggleCard(BuildContext context) {
    return Card(
      child: SwitchListTile(
        dense: true,
        title: const Text('Filtered source'),
        subtitle: Text(
          _filteredSource
              ? 'Showing: tech, healthcare'
              : 'Showing: tech, finance, healthcare, manufacturing, retail, other',
        ),
        value: _filteredSource,
        onChanged: (v) => setState(() => _filteredSource = v),
      ),
    );
  }

  Widget _pendingVariant(
      BuildContext context, String className, String note) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    className,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Phase 2', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(note, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final opt in _options)
                  Chip(
                    label: Text(opt, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    return InfoPanel(
      title: 'Bound values',
      children: [
        TomMultiObservableBuilder(
          observables: [
            _filterChips,
            _multiCheckbox,
            _segmented,
            _radioGroup,
            _choiceChips,
          ],
          builder: (context) {
            final rows = [
              ('filterChips', _list(_filterChips)),
              ('multiCheckbox', _list(_multiCheckbox)),
              ('segmented', _segmented.get()),
              ('radioGroup', _radioGroup.get()),
              ('choiceChips', _choiceChips.get()),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (name, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value.isEmpty ? '—' : value,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
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
    );
  }

  static String _list(TomList<TomString> list) =>
      '[${list.toList().map((e) => e.get()).join(", ")}]';
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
