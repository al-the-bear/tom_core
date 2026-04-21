/// Phase 4 backing state — Demos K (enum/object/lookup) and L (file +
/// nullable variants). Mirrors the state organisation used in
/// `phase3_state.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Domain types reused across Demo K
// ---------------------------------------------------------------------------

/// Closed-set enum bound to enum dropdown / segmented / radio / chips.
enum Priority { low, medium, high, critical }

extension PriorityX on Priority {
  String get label => switch (this) {
        Priority.low => 'Low',
        Priority.medium => 'Medium',
        Priority.high => 'High',
        Priority.critical => 'Critical',
      };
}

/// Closed-set enum used by the multi-select chips row.
enum Tag { backend, frontend, design, devops, qa }

extension TagX on Tag {
  String get label => switch (this) {
        Tag.backend => 'Backend',
        Tag.frontend => 'Frontend',
        Tag.design => 'Design',
        Tag.devops => 'DevOps',
        Tag.qa => 'QA',
      };
}

/// Domain object for the object dropdown / object filter chips rows.
@immutable
class Country {
  final String code;
  final String name;
  const Country(this.code, this.name);

  @override
  bool operator ==(Object other) => other is Country && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$name ($code)';
}

/// Domain object for the search / lookup rows. ~5 000 instances are
/// generated lazily for the search demo to exercise the in-process
/// substring filter.
@immutable
class City {
  final int id;
  final String name;
  final String country;
  const City(this.id, this.name, this.country);

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name, $country';
}

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

class _PrioritySource extends TomSelectableSource<Priority> {
  @override
  Future<List<SelectableItem<Priority>>> getItems() async => [
        for (final p in Priority.values)
          SelectableItem<Priority>(value: p, label: p.label),
      ];
}

class _TagSource extends TomSelectableSource<Tag> {
  @override
  Future<List<SelectableItem<Tag>>> getItems() async => [
        for (final t in Tag.values)
          SelectableItem<Tag>(value: t, label: t.label),
      ];
}

class _CountrySource extends TomSelectableSource<Country> {
  static const _countries = <Country>[
    Country('US', 'United States'),
    Country('DE', 'Germany'),
    Country('FR', 'France'),
    Country('JP', 'Japan'),
    Country('BR', 'Brazil'),
    Country('IN', 'India'),
    Country('AU', 'Australia'),
  ];

  @override
  Future<List<SelectableItem<Country>>> getItems() async => [
        for (final c in _countries)
          SelectableItem<Country>(value: c, label: c.toString()),
      ];
}

/// Synthesises a large list (~5 000) of `City` items by interleaving a
/// short root list with numbered suffixes. Used to exercise the search
/// field's in-process substring filter.
class _BigCitySource extends TomSelectableSource<City> {
  static const _roots = <(String, String)>[
    ('Berlin', 'DE'),
    ('Paris', 'FR'),
    ('Tokyo', 'JP'),
    ('Sydney', 'AU'),
    ('Toronto', 'CA'),
    ('Madrid', 'ES'),
    ('Rome', 'IT'),
    ('Vienna', 'AT'),
    ('Oslo', 'NO'),
    ('Helsinki', 'FI'),
  ];

  late final List<SelectableItem<City>> _cache = _build();

  List<SelectableItem<City>> _build() {
    final out = <SelectableItem<City>>[];
    var id = 0;
    for (var i = 0; i < 500; i++) {
      for (final (name, country) in _roots) {
        final fullName = i == 0 ? name : '$name $i';
        final city = City(id, fullName, country);
        out.add(SelectableItem<City>(
          value: city,
          label: '$fullName, $country',
        ));
        id++;
      }
    }
    return out;
  }

  @override
  Future<List<SelectableItem<City>>> getItems() async => _cache;
}

/// Smaller country list reused by the lookup-dialog row.
class _LookupCountrySource extends TomSelectableSource<Country> {
  static const _items = <Country>[
    Country('US', 'United States'),
    Country('DE', 'Germany'),
    Country('FR', 'France'),
    Country('JP', 'Japan'),
    Country('BR', 'Brazil'),
    Country('IN', 'India'),
    Country('AU', 'Australia'),
    Country('CA', 'Canada'),
    Country('ES', 'Spain'),
    Country('IT', 'Italy'),
    Country('AT', 'Austria'),
    Country('NO', 'Norway'),
    Country('FI', 'Finland'),
    Country('SE', 'Sweden'),
    Country('CH', 'Switzerland'),
    Country('NL', 'Netherlands'),
    Country('BE', 'Belgium'),
    Country('IE', 'Ireland'),
    Country('PT', 'Portugal'),
  ];

  @override
  Future<List<SelectableItem<Country>>> getItems() async => [
        for (final c in _items)
          SelectableItem<Country>(value: c, label: c.toString()),
      ];
}

// Public source instances reused across the form definitions.
final TomSelectableSource<Priority> phase4PrioritySource = _PrioritySource();
final TomSelectableSource<Tag> phase4TagSource = _TagSource();
final TomSelectableSource<Country> phase4CountrySource = _CountrySource();
final TomSelectableSource<City> phase4CitySource = _BigCitySource();
final TomSelectableSource<Country> phase4LookupCountrySource =
    _LookupCountrySource();

// ---------------------------------------------------------------------------
// Backing TomClasses
// ---------------------------------------------------------------------------

// Demo K (enum / object / lookup) doesn't ship a backing `TomClass` —
// the kernel doesn't expose `TomObject<T>` for arbitrary `T` (no enum or
// domain-object wrapper), so the demo lets each `TomFormEnumX<T>` /
// `TomFormObjectX<T>` field own its observable directly. The fields'
// own values still drive the inspector / change log just fine.

@tomReflector
class FileNullableDemoState extends TomClass {
  late final notes = TomNString(null);
  late final age = TomNInt(null);
  late final score = TomNDouble(null);
  late final birthday = TomNDateTime(null);
}

FileNullableDemoState phase4FileNullableState = FileNullableDemoState();
