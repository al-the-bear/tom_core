/// Demo K — Enum, object, search, and lookup fields (Phase 4).
///
/// Showcases the enum + object selection family side-by-side:
///
///   * Enum (Priority) — Dropdown / Segmented / RadioGroup, all bound
///     to the same `_priorityX` field per row so the variants are
///     swappable line-by-line.
///   * Enum (Tag) — multi-select FilterChips → `List<Tag>`.
///   * Object (Country) — single-select Dropdown + multi-select chips
///     against a domain object.
///   * Search (City, ~5 000 entries) — `TomFormSearchInput<City>`
///     exercises the in-process substring filter on a large source.
///   * Lookup dialog (Country) — modal browse + filter, returns the
///     picked value to a compact form row.
///
/// Demo K does **not** bind to a `TomClass` — the kernel only provides
/// `TomString` / `TomInt` / `TomDouble` / `TomBool` / `TomDateTime` (and
/// nullable variants). There's no `TomObject<T>` for arbitrary `T`, so
/// each enum/object field owns its own observable directly. The right
/// column shows the live values + a change log so the binding shape is
/// visible without a backing TomClass.
library;

import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../common/demo_scaffold.dart';
import '../panels/info_panel.dart';
import '../state/phase4_state.dart';

class DemoKEnumObject extends StatefulWidget {
  const DemoKEnumObject({super.key});

  @override
  State<DemoKEnumObject> createState() => _DemoKEnumObjectState();
}

// ---------------------------------------------------------------------------
// One-line entry for the change log.
// ---------------------------------------------------------------------------

class _LogEntry {
  final DateTime timestamp;
  final String fieldName;
  final String value;
  _LogEntry(this.fieldName, this.value) : timestamp = DateTime.now();
}

class _DemoKEnumObjectState extends State<DemoKEnumObject> {
  // --- Fields ------------------------------------------------------------
  // All fields are constructed inside a single 'demoK' scope so resource
  // lookups read consistently (even though we don't use any).

  late final TomFormEnumDropdown<Priority> _priorityDropdown;
  late final TomFormEnumSegmented<Priority> _prioritySegmented;
  late final TomFormEnumRadioGroup<Priority> _priorityRadio;
  late final TomFormEnumFilterChips<Tag> _tagsChips;
  late final TomFormObjectDropdown<Country> _countryDropdown;
  late final TomFormObjectFilterChips<Country> _countriesChips;
  late final TomFormSearchInput<City> _citySearch;
  late final TomFormLookupDialog<Country> _countryLookup;
  late final TomFormIntFilterChips _pointSizes;

  // --- Inspector state ---------------------------------------------------

  final List<_LogEntry> _log = [];
  // Hold strong refs — TomObservable stores observers via WeakReference.
  final List<Object> _observers = [];

  @override
  void initState() {
    super.initState();
    TomScope.withScope('demoK', () {
      _priorityDropdown = TomFormEnumDropdown<Priority>(
        'priorityDropdown',
        Priority.medium,
        source: phase4PrioritySource,
        labelTextOverride: 'Priority (dropdown)',
        descriptionTextOverride:
            'Single-select enum via DropdownButtonFormField',
      );
      _prioritySegmented = TomFormEnumSegmented<Priority>(
        'prioritySegmented',
        Priority.high,
        source: phase4PrioritySource,
        labelTextOverride: 'Priority (segmented)',
        descriptionTextOverride: 'Single-select enum via SegmentedButton',
      );
      _priorityRadio = TomFormEnumRadioGroup<Priority>(
        'priorityRadio',
        Priority.low,
        source: phase4PrioritySource,
        labelTextOverride: 'Priority (radio)',
        descriptionTextOverride: 'Single-select enum via Radio rows',
      );
      _tagsChips = TomFormEnumFilterChips<Tag>(
        'tags',
        const [Tag.backend, Tag.devops],
        source: phase4TagSource,
        labelTextOverride: 'Tags (multi)',
        descriptionTextOverride:
            'Multi-select enum via FilterChips → List<Tag>',
      );
      _countryDropdown = TomFormObjectDropdown<Country>(
        'country',
        const Country('US', 'United States'),
        source: phase4CountrySource,
        labelTextOverride: 'Country (object)',
        descriptionTextOverride: 'Single-select Country object via dropdown',
      );
      _countriesChips = TomFormObjectFilterChips<Country>(
        'countries',
        const [Country('DE', 'Germany'), Country('FR', 'France')],
        source: phase4CountrySource,
        labelTextOverride: 'Countries (multi)',
        descriptionTextOverride: 'Multi-select Country objects via FilterChips',
      );
      _citySearch = TomFormSearchInput<City>(
        'city',
        const City(0, 'Berlin', 'DE'),
        source: phase4CitySource,
        labelTextOverride: 'City search (~5 000 items)',
        hintTextOverride: 'Type a city name…',
        descriptionTextOverride:
            'Type-ahead Autocomplete with in-process substring filter',
        labelOf: (c) => c.toString(),
      );
      _countryLookup = TomFormLookupDialog<Country>(
        'lookupCountry',
        const Country('JP', 'Japan'),
        source: phase4LookupCountrySource,
        labelTextOverride: 'Country (lookup dialog)',
        dialogTitle: 'Pick a country',
        descriptionTextOverride:
            'Read-only field; tap to open a filterable dialog',
        labelOf: (c) => c.toString(),
      );
      _pointSizes = TomFormIntFilterChips(
        'pointSizes',
        const [10, 14],
        source: phase4PointSizeSource,
        labelTextOverride: 'Point sizes (multi)',
        descriptionTextOverride:
            'Multi-select int values via FilterChips → List<int>',
      );
    });

    // Wire every field to the change log.
    _observers.addAll([
      _priorityDropdown >>
          (_) => _record('priorityDropdown', _priorityDropdown.get().label),
      _prioritySegmented >>
          (_) => _record('prioritySegmented', _prioritySegmented.get().label),
      _priorityRadio >>
          (_) => _record('priorityRadio', _priorityRadio.get().label),
      _tagsChips >>
          (_) => _record(
            'tags',
            '[${_tagsChips.get().map((t) => t.label).join(", ")}]',
          ),
      _countryDropdown >>
          (_) => _record('country', _countryDropdown.get().toString()),
      _countriesChips >>
          (_) => _record(
            'countries',
            '[${_countriesChips.get().map((c) => c.code).join(", ")}]',
          ),
      _citySearch >> (_) => _record('city', _citySearch.get().toString()),
      _countryLookup >>
          (_) => _record('lookupCountry', _countryLookup.get().toString()),
      _pointSizes >>
          (_) => _record('pointSizes', '[${_pointSizes.get().join(", ")}]'),
    ]);
  }

  void _record(String name, String value) {
    setState(() {
      _log.insert(0, _LogEntry(name, value));
      if (_log.length > 30) _log.removeLast();
    });
  }

  @override
  void dispose() {
    _priorityDropdown.dispose();
    _prioritySegmented.dispose();
    _priorityRadio.dispose();
    _tagsChips.dispose();
    _countryDropdown.dispose();
    _countriesChips.dispose();
    _citySearch.dispose();
    _countryLookup.dispose();
    _pointSizes.dispose();
    super.dispose();
  }

  // --- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Demo K — Enum, Object & Lookup',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
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
        _intro(context),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Enum (Priority) — single-select variants',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _priorityDropdown.widget,
              const SizedBox(height: 8),
              _prioritySegmented.widget,
              const SizedBox(height: 8),
              _priorityRadio.widget,
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Enum (Tag) — multi-select chips',
          child: _tagsChips.widget,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Object (Country) — single-select dropdown',
          child: _countryDropdown.widget,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Object (Country) — multi-select chips',
          child: _countriesChips.widget,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Search (City) — ~5 000-item source',
          child: _citySearch.widget,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Lookup dialog (Country) — modal browse',
          child: _countryLookup.widget,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          title: 'Int list (point sizes) — multi-select chips',
          child: _pointSizes.widget,
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
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
              '• Phase 4 enum & object families — Dropdown / Segmented / '
              'Radio (single) and FilterChips (multi).\n'
              '• Object dropdowns + chips against a domain Country class.\n'
              '• Search field with a ~5 000-item source (in-process '
              'substring filter, capped at 50 visible results).\n'
              '• Lookup dialog — read-only row + filterable modal picker.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  // --- Info column -------------------------------------------------------

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
      observables: [
        _priorityDropdown,
        _prioritySegmented,
        _priorityRadio,
        _tagsChips,
        _countryDropdown,
        _countriesChips,
        _citySearch,
        _countryLookup,
        _pointSizes,
      ],
      builder: (context) {
        final theme = Theme.of(context);
        final rows = [
          ('priorityDropdown', _priorityDropdown.get().label),
          ('prioritySegmented', _prioritySegmented.get().label),
          ('priorityRadio', _priorityRadio.get().label),
          ('tags', '[${_tagsChips.get().map((t) => t.label).join(", ")}]'),
          ('country', _countryDropdown.get().toString()),
          (
            'countries',
            '[${_countriesChips.get().map((c) => c.code).join(", ")}]',
          ),
          ('city', _citySearch.get().toString()),
          ('lookupCountry', _countryLookup.get().toString()),
          ('pointSizes', '[${_pointSizes.get().join(", ")}]'),
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
                      width: 130,
                      child: Text(name, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(
                        value.isEmpty ? '—' : value,
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
        'No writes yet — interact with any field to record a change.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
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
                  width: 110,
                  child: Text(
                    e.fieldName,
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
