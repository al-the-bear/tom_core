import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';

// ---------------------------------------------------------------------------
// Demo E — Selection Variants (Phase 2)
// ---------------------------------------------------------------------------

/// Two-column demo covering the spec's Phase 2 selection-variants scope:
///
///   * Five single-select / multi-select flavours — FilterChips,
///     MultiCheckbox, Segmented, RadioGroup, ChoiceChips — rendered
///     side-by-side against one shared [TomSelectableSource].
///   * Each variant is wired to its spec-aligned binding shape: multi-select
///     flavours write a `TomList<TomString>`, single-select flavours write
///     a `TomString`. The right-hand panel prints the live bindings + a
///     change log so the shape difference is visible.
///   * A "filtered source" switch flips the shared source at runtime
///     between the full static catalogue and a 2-item subset so the
///     dependency on an observable source (rather than hard-coded
///     options) is demonstrable.
///
/// The variants use plain Material widgets (FilterChip, CheckboxListTile,
/// SegmentedButton, RadioListTile, ChoiceChip) as stand-ins. When the
/// Phase 2 concrete widgets (`TomFormStringFilterChips`,
/// `TomFormStringMultiCheckbox`, `TomFormStringSegmented`,
/// `TomFormStringRadioGroup`, `TomFormStringChoiceChips`) land they drop
/// in as one-line swaps — the bindings and the source are already correct.
class DemoESelectionVariants extends StatefulWidget {
  const DemoESelectionVariants({super.key});

  @override
  State<DemoESelectionVariants> createState() => _DemoESelectionVariantsState();
}

// ---------------------------------------------------------------------------
// Two pre-built sources so the toggle is a simple field swap.
// ---------------------------------------------------------------------------

final _fullSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'tech', label: 'Technology'),
  const SelectableItem(value: 'finance', label: 'Finance'),
  const SelectableItem(value: 'healthcare', label: 'Healthcare'),
  const SelectableItem(value: 'manufacturing', label: 'Manufacturing'),
  const SelectableItem(value: 'retail', label: 'Retail'),
  const SelectableItem(value: 'other', label: 'Other'),
]);

final _filteredSource = StaticSelectableSource<String>([
  const SelectableItem(value: 'tech', label: 'Technology'),
  const SelectableItem(value: 'healthcare', label: 'Healthcare'),
]);

// ---------------------------------------------------------------------------
// Log entry for the inspector panel — one line per observable write.
// ---------------------------------------------------------------------------

class _LogEntry {
  final DateTime timestamp;
  final String variant;
  final String value;
  _LogEntry(this.variant, this.value) : timestamp = DateTime.now();
}

class _DemoESelectionVariantsState extends State<DemoESelectionVariants> {
  // --- Observables — match the Phase 2 widgets' binding shape. -----------

  // Multi-select flavours write into a TomList<TomString>.
  final _filterChipsSelection = TomList<TomString>();
  final _multiCheckboxSelection = TomList<TomString>();

  // Single-select flavours write into a TomString.
  final _segmented = TomString('');
  final _radioGroup = TomString('');
  final _choiceChips = TomString('');

  // Boolean flavours — write into a TomBool.
  final _boolCheckbox = TomBool(false);
  final _boolSwitch = TomBool(false);
  final _boolToggle = TomBool(false);

  // --- Source & items ------------------------------------------------------

  bool _useFiltered = false;
  TomSelectableSource<String> get _activeSource =>
      _useFiltered ? _filteredSource : _fullSource;
  List<SelectableItem<String>> _items = const [];

  // --- Inspector state -----------------------------------------------------

  final List<_LogEntry> _log = [];

  // Hold strong refs — TomObservable stores observers via WeakReference.
  final List<Object> _observers = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _observers.addAll([
      _filterChipsSelection >>
          (_) => _record('filterChips', _listLabel(_filterChipsSelection)),
      _multiCheckboxSelection >>
          (_) => _record('multiCheckbox', _listLabel(_multiCheckboxSelection)),
      _segmented >> (o) => _record('segmented', (o as TomString).get()),
      _radioGroup >> (o) => _record('radioGroup', (o as TomString).get()),
      _choiceChips >> (o) => _record('choiceChips', (o as TomString).get()),
      _boolCheckbox >> (o) => _record('boolCheckbox', '${(o as TomBool).get()}'),
      _boolSwitch >> (o) => _record('boolSwitch', '${(o as TomBool).get()}'),
      _boolToggle >> (o) => _record('boolToggle', '${(o as TomBool).get()}'),
    ]);
  }

  Future<void> _loadItems() async {
    final items = await _activeSource.getItems();
    if (!mounted) return;
    setState(() => _items = items);
    _pruneInvalid();
  }

  void _record(String variant, String value) {
    setState(() {
      _log.insert(0, _LogEntry(variant, value));
      if (_log.length > 30) _log.removeLast();
    });
  }

  void _toggleSource(bool useFiltered) {
    setState(() => _useFiltered = useFiltered);
    // _loadItems awaits the source and then prunes selections that the new
    // source no longer exposes — same convention TomFormStringDropdown
    // uses via its C13 "reset if value missing" rule.
    _loadItems();
  }

  void _pruneInvalid() {
    final valid = _items.map((e) => e.value).toSet();
    _filterChipsSelection.removeWhere((o) => !valid.contains(o.get()));
    _multiCheckboxSelection.removeWhere((o) => !valid.contains(o.get()));
    if (_segmented.get().isNotEmpty && !valid.contains(_segmented.get())) {
      _segmented | '';
    }
    if (_radioGroup.get().isNotEmpty && !valid.contains(_radioGroup.get())) {
      _radioGroup | '';
    }
    if (_choiceChips.get().isNotEmpty && !valid.contains(_choiceChips.get())) {
      _choiceChips | '';
    }
  }

  // --- Multi-select helpers ----------------------------------------------

  static Set<String> _selected(TomList<TomString> list) =>
      list.toList().map((e) => e.get()).toSet();

  void _toggleMulti(TomList<TomString> list, String value, bool selected) {
    if (selected) {
      if (!_selected(list).contains(value)) list.add(TomString(value));
    } else {
      list.removeWhere((o) => o.get() == value);
    }
  }

  static String _listLabel(TomList<TomString> list) =>
      '[${list.toList().map((e) => e.get()).join(", ")}]';

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
        _buildSourceToggleCard(context),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormStringFilterChips — multi-select',
          subtitle: 'Writes TomList<TomString> (filterChipsSelection)',
          child: _buildFilterChips(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormStringMultiCheckbox — multi-select',
          subtitle: 'Writes TomList<TomString> (multiCheckboxSelection)',
          child: _buildMultiCheckbox(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormStringSegmented — single-select',
          subtitle: 'Writes TomString (segmented)',
          child: _buildSegmented(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormStringRadioGroup — single-select',
          subtitle: 'Writes TomString (radioGroup)',
          child: _buildRadioGroup(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormStringChoiceChips — single-select',
          subtitle: 'Writes TomString (choiceChips)',
          child: _buildChoiceChips(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormBoolCheckbox — boolean',
          subtitle: 'Writes TomBool (boolCheckbox)',
          child: _buildBoolCheckbox(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormBoolSwitch — boolean',
          subtitle: 'Writes TomBool (boolSwitch)',
          child: _buildBoolSwitch(),
        ),
        const SizedBox(height: 12),
        _variantCard(
          context,
          title: 'TomFormBoolToggle — boolean',
          subtitle: 'Writes TomBool (boolToggle)',
          child: _buildBoolToggle(),
        ),
      ],
    );
  }

  Widget _buildBoolCheckbox() => TomMultiObservableBuilder(
        observables: [_boolCheckbox],
        builder: (context) => CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Agree to terms'),
          value: _boolCheckbox.get(),
          onChanged: (v) => _boolCheckbox | (v ?? false),
        ),
      );

  Widget _buildBoolSwitch() => TomMultiObservableBuilder(
        observables: [_boolSwitch],
        builder: (context) => SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable notifications'),
          value: _boolSwitch.get(),
          onChanged: (v) => _boolSwitch | v,
        ),
      );

  Widget _buildBoolToggle() => TomMultiObservableBuilder(
        observables: [_boolToggle],
        builder: (context) => Row(
          children: [
            const Expanded(child: Text('Public visibility')),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('off')),
                ButtonSegment(value: true, label: Text('on')),
              ],
              selected: {_boolToggle.get()},
              onSelectionChanged: (s) => _boolToggle | s.first,
              showSelectedIcon: false,
            ),
          ],
        ),
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
            const _Bullet(
                'Every single- and multi-select flavour renders against '
                'one shared TomSelectableSource<String>.'),
            const _Bullet(
                'Each variant is wired to the Phase 2 binding shape: '
                'multi-select → TomList<TomString>, single-select → '
                'TomString. The right-hand inspector shows every write '
                'live and keeps a change log so the shape is obvious.'),
            const _Bullet(
                'Switch "Filtered source" to swap the shared source '
                'between the full catalogue and a 2-item subset at '
                'runtime — demonstrates source observability and verifies '
                'invalid selections are dropped on shrink.'),
            const _Bullet(
                'Material widgets act as stand-ins; Phase 2 drops in '
                'TomFormString{FilterChips,MultiCheckbox,Segmented,'
                'RadioGroup,ChoiceChips} one line per block.'),
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
        subtitle: Text(_useFiltered
            ? 'Active: 2-item subset (tech, healthcare)'
            : 'Active: full 6-item catalogue'),
        value: _useFiltered,
        onChanged: _toggleSource,
      ),
    );
  }

  Widget _variantCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
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
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  // --- Variant builders ----------------------------------------------------

  Widget _buildFilterChips() {
    return TomMultiObservableBuilder(
      observables: [_filterChipsSelection],
      builder: (context) {
        final sel = _selected(_filterChipsSelection);
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final item in _items)
              FilterChip(
                label: Text(item.label),
                selected: sel.contains(item.value),
                onSelected: (on) =>
                    _toggleMulti(_filterChipsSelection, item.value, on),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMultiCheckbox() {
    return TomMultiObservableBuilder(
      observables: [_multiCheckboxSelection],
      builder: (context) {
        final sel = _selected(_multiCheckboxSelection);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in _items)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.label),
                value: sel.contains(item.value),
                onChanged: (v) => _toggleMulti(
                    _multiCheckboxSelection, item.value, v ?? false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSegmented() {
    return TomMultiObservableBuilder(
      observables: [_segmented],
      builder: (context) {
        if (_items.isEmpty) return const SizedBox.shrink();
        final value = _segmented.get();
        final selected =
            _items.any((i) => i.value == value) ? {value} : <String>{};
        return SegmentedButton<String>(
          segments: [
            for (final item in _items)
              ButtonSegment<String>(
                value: item.value,
                label: Text(item.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
          selected: selected,
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) => _segmented | (s.isEmpty ? '' : s.first),
        );
      },
    );
  }

  Widget _buildRadioGroup() {
    return TomMultiObservableBuilder(
      observables: [_radioGroup],
      builder: (context) {
        final value = _radioGroup.get();
        return RadioGroup<String>(
          groupValue: value.isEmpty ? null : value,
          onChanged: (v) => _radioGroup | (v ?? ''),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in _items)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  value: item.value,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChoiceChips() {
    return TomMultiObservableBuilder(
      observables: [_choiceChips],
      builder: (context) {
        final value = _choiceChips.get();
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final item in _items)
              ChoiceChip(
                label: Text(item.label),
                selected: value == item.value,
                onSelected: (on) => _choiceChips | (on ? item.value : ''),
              ),
          ],
        );
      },
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
        InfoPanel(
          title: 'Change log',
          children: [_buildLog(context)],
        ),
      ],
    );
  }

  Widget _buildBindingsTable(BuildContext context) {
    return TomMultiObservableBuilder(
      observables: [
        _filterChipsSelection,
        _multiCheckboxSelection,
        _segmented,
        _radioGroup,
        _choiceChips,
        _boolCheckbox,
        _boolSwitch,
        _boolToggle,
      ],
      builder: (context) {
        final theme = Theme.of(context);
        final rows = [
          ('filterChips', _listLabel(_filterChipsSelection)),
          ('multiCheckbox', _listLabel(_multiCheckboxSelection)),
          ('segmented', _segmented.get()),
          ('radioGroup', _radioGroup.get()),
          ('choiceChips', _choiceChips.get()),
          ('boolCheckbox', '${_boolCheckbox.get()}'),
          ('boolSwitch', '${_boolSwitch.get()}'),
          ('boolToggle', '${_boolToggle.get()}'),
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
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value.isEmpty ? '—' : value,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
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
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
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
