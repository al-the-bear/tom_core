import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';
import 'demo_widgets.dart';

// ---------------------------------------------------------------------------
// Demo E — Selection Variants
// ---------------------------------------------------------------------------

/// Two-column demo covering the selection-variants scope:
///
///   * The five concrete selection fields that ship in `tom_flutter_ui` —
///     [TomFormStringFilterChips], [TomFormStringMultiCheckbox],
///     [TomFormStringSegmented], [TomFormStringRadioGroup],
///     [TomFormStringChoiceChips] — rendered side-by-side against **one
///     shared** [TomMutableSelectableSource], plus the three boolean
///     renderings for contrast.
///   * The two binding shapes side-by-side: multi-select fields are
///     `TomField<List<String>>` and bind a plain `List<String>`;
///     single-select fields are `TomField<String>`. The right-hand panel
///     prints the live bindings and a change log, so the difference is
///     visible rather than merely asserted.
///   * A "filtered source" switch that calls
///     [TomMutableSelectableSource.setItems] at runtime, shrinking the shared
///     catalogue from six items to two. Nothing in this demo reacts to that:
///     each field subscribes to the source's `itemsStream` itself, re-renders,
///     and reconciles its own value. That reconciliation differs by arity and
///     is the point of the switch — multi-select fields *drop* the values that
///     vanished, single-select fields fall back to the **first enabled item**
///     rather than to empty.
class DemoESelectionVariants extends StatefulWidget {
  const DemoESelectionVariants({super.key});

  @override
  State<DemoESelectionVariants> createState() => _DemoESelectionVariantsState();
}

// ---------------------------------------------------------------------------
// The two catalogues the "filtered source" switch flips between.
// ---------------------------------------------------------------------------

const _fullCatalogue = <TomSelectableItem<String>>[
  TomSelectableItem(value: 'tech', label: 'Technology'),
  TomSelectableItem(value: 'finance', label: 'Finance'),
  TomSelectableItem(value: 'healthcare', label: 'Healthcare'),
  TomSelectableItem(value: 'manufacturing', label: 'Manufacturing'),
  TomSelectableItem(value: 'retail', label: 'Retail'),
  TomSelectableItem(value: 'other', label: 'Other'),
];

const _filteredCatalogue = <TomSelectableItem<String>>[
  TomSelectableItem(value: 'tech', label: 'Technology'),
  TomSelectableItem(value: 'healthcare', label: 'Healthcare'),
];

// ---------------------------------------------------------------------------
// Log entry for the inspector panel — one line per field write.
// ---------------------------------------------------------------------------

class _LogEntry {
  final DateTime timestamp;
  final String variant;
  final String value;
  _LogEntry(this.variant, this.value) : timestamp = DateTime.now();
}

class _DemoESelectionVariantsState extends State<DemoESelectionVariants> {
  /// One source shared by all five selection fields, so the switch below
  /// moves every one of them at once.
  final _source = TomMutableSelectableSource<String>(_fullCatalogue);

  // --- Multi-select — TomField<List<String>>. ------------------------------
  late final TomFormStringFilterChips _filterChips;
  late final TomFormStringMultiCheckbox _multiCheckbox;

  // --- Single-select — TomField<String>. ----------------------------------
  //
  // These start on a real catalogue value rather than on `''`: an empty
  // value makes TomFormStringSegmented fall back to painting its first
  // segment as selected, which would put the rendering and the bindings
  // panel into visible disagreement before the user touches anything.
  late final TomFormStringSegmented _segmented;
  late final TomFormStringRadioGroup _radioGroup;
  late final TomFormStringChoiceChips _choiceChips;

  // --- Boolean renderings, for contrast with the selection arity. ---------
  late final TomFormBoolCheckbox _boolCheckbox;
  late final TomFormBoolSwitch _boolSwitch;
  late final TomFormBoolToggle _boolToggle;

  late final List<TomField<Object>> _allFields = [
    _filterChips,
    _multiCheckbox,
    _segmented,
    _radioGroup,
    _choiceChips,
    _boolCheckbox,
    _boolSwitch,
    _boolToggle,
  ];

  // --- Source toggle -------------------------------------------------------

  bool _useFiltered = false;

  // --- Inspector state -----------------------------------------------------

  final List<_LogEntry> _log = [];

  /// Unregisters the change-log observers on dispose. Observers are held
  /// weakly, so retaining the cancellers is also what keeps them alive.
  final List<void Function()> _observerCancels = [];

  @override
  void initState() {
    super.initState();

    _filterChips = TomFormStringFilterChips(
      'filterChips',
      const [],
      source: _source,
      labelTextOverride: 'TomFormStringFilterChips (filterChips)',
      descriptionTextOverride: 'Multi-select — binds List<String>',
    );
    _multiCheckbox = TomFormStringMultiCheckbox(
      'multiCheckbox',
      const [],
      source: _source,
      labelTextOverride: 'TomFormStringMultiCheckbox (multiCheckbox)',
      descriptionTextOverride: 'Multi-select — binds List<String>',
    );

    _segmented = TomFormStringSegmented(
      'segmented',
      'tech',
      source: _source,
      labelTextOverride: 'TomFormStringSegmented (segmented)',
      descriptionTextOverride: 'Single-select — binds String',
    );
    _radioGroup = TomFormStringRadioGroup(
      'radioGroup',
      'tech',
      source: _source,
      labelTextOverride: 'TomFormStringRadioGroup (radioGroup)',
      descriptionTextOverride: 'Single-select — binds String',
    );
    _choiceChips = TomFormStringChoiceChips(
      'choiceChips',
      'tech',
      source: _source,
      labelTextOverride: 'TomFormStringChoiceChips (choiceChips)',
      descriptionTextOverride: 'Single-select — binds String',
    );

    _boolCheckbox = TomFormBoolCheckbox(
      'boolCheckbox',
      false,
      labelTextOverride: 'TomFormBoolCheckbox (boolCheckbox)',
    );
    _boolSwitch = TomFormBoolSwitch(
      'boolSwitch',
      false,
      labelTextOverride: 'TomFormBoolSwitch (boolSwitch)',
    );
    _boolToggle = TomFormBoolToggle(
      'boolToggle',
      false,
      labelTextOverride: 'TomFormBoolToggle (boolToggle)',
    );

    for (final field in _allFields) {
      final observer = field >> (_) => _record(field.tomId, _label(field));
      _observerCancels.add(() => field.removeObserver(observer));
    }
  }

  /// Renders any field's current value for the panel and the log.
  static String _label(TomField<Object> field) {
    final value = field.get();
    return value is List ? '[${value.join(", ")}]' : '$value';
  }

  /// An empty selection prints as a dash — both arities can reach one, and
  /// a blank cell reads as a rendering bug rather than as "nothing selected".
  static String _emptyAsDash(String rendered) =>
      rendered.isEmpty || rendered == '[]' ? '—' : rendered;

  void _record(String variant, String value) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _LogEntry(variant, value));
      if (_log.length > 30) _log.removeLast();
    });
  }

  /// Swaps the catalogue on the shared source.
  ///
  /// This is the whole handler: the fields hear the new items through
  /// `itemsStream` and reconcile themselves. The demo does not prune, reset
  /// or rebuild anything.
  void _toggleSource(bool useFiltered) {
    setState(() => _useFiltered = useFiltered);
    _source.setItems(useFiltered ? _filteredCatalogue : _fullCatalogue);
  }

  @override
  void dispose() {
    for (final cancel in _observerCancels) {
      cancel();
    }
    _observerCancels.clear();
    for (final field in _allFields) {
      field.dispose();
    }
    _source.dispose();
    super.dispose();
  }

  // --- Build ---------------------------------------------------------------

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

  Widget _buildFormColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroCard(context),
        const SizedBox(height: 12),
        _buildSourceToggleCard(context),
        const SizedBox(height: 12),
        _variantGroupCard(
          context,
          title: 'Multi-select — TomField<List<String>>',
          fields: [_filterChips, _multiCheckbox],
        ),
        const SizedBox(height: 12),
        _variantGroupCard(
          context,
          title: 'Single-select — TomField<String>',
          fields: [_segmented, _radioGroup, _choiceChips],
        ),
        const SizedBox(height: 12),
        _variantGroupCard(
          context,
          title: 'Boolean — TomField<bool>',
          fields: [_boolCheckbox, _boolSwitch, _boolToggle],
        ),
      ],
    );
  }

  /// Renders one field, keyed by its `tomId`.
  ///
  /// Why the key: several fields repeat the same inner Material widgets (two
  /// chip rows, two segmented buttons), so a widget test needs a stable
  /// per-field anchor to scope its finders to one row. The key is the only
  /// thing here that exists for the tests.
  Widget _fieldRow(TomField<Object> field) => Padding(
    key: ValueKey('field-${field.tomId}'),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: field.widget,
  );

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
            const DemoBullet(
              'All five selection renderings — filter chips, multi-checkbox, '
              'segmented, radio group and choice chips — draw from one shared '
              'TomMutableSelectableSource<String>.',
            ),
            const DemoBullet(
              'The two binding shapes side-by-side: multi-select fields bind '
              'a plain List<String>, single-select fields bind a String. The '
              'right-hand inspector shows every write live and keeps a change '
              'log, so the shapes are visible rather than merely claimed.',
            ),
            const DemoBullet(
              'Switch "Filtered source" to shrink the shared catalogue from '
              'six items to two at runtime. The fields subscribe to the '
              'source themselves — the demo prunes nothing.',
            ),
            const DemoBullet(
              'Watch the two arities reconcile differently on that shrink: '
              'multi-select drops the values that vanished, single-select '
              'falls back to the first enabled item rather than to empty.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceToggleCard(BuildContext context) {
    return Card(
      child: SwitchListTile(
        dense: true,
        title: const Text('Filtered source'),
        subtitle: Text(
          _useFiltered
              ? 'Active: 2-item subset (tech, healthcare)'
              : 'Active: full 6-item catalogue',
        ),
        value: _useFiltered,
        onChanged: _toggleSource,
      ),
    );
  }

  Widget _variantGroupCard(
    BuildContext context, {
    required String title,
    required List<TomField<Object>> fields,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            ...fields.map(_fieldRow),
          ],
        ),
      ),
    );
  }

  // --- Info column ---------------------------------------------------------

  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          title: 'Live bindings',
          children: [_buildBindingsTable(context)],
        ),
        const SizedBox(height: 12),
        InfoPanel(title: 'Change log', children: [_buildLog(context)]),
      ],
    );
  }

  Widget _buildBindingsTable(BuildContext context) {
    return TomMultiObservableBuilder(
      observables: _allFields,
      builder: (context) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in _allFields)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        field.tomId,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _emptyAsDash(_label(field)),
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
    );
  }

  Widget _buildLog(BuildContext context) {
    final theme = Theme.of(context);
    if (_log.isEmpty) {
      return Text(
        'No writes yet — tap any variant to log a binding update.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _log.length,
        itemBuilder: (context, i) {
          final e = _log[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stamp(e.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 92,
                  child: Text(
                    e.variant,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value.isEmpty ? '—' : e.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _stamp(DateTime t) {
    String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
    return '${p(t.hour)}:${p(t.minute)}:${p(t.second)}.${p(t.millisecond, 3)}';
  }
}
