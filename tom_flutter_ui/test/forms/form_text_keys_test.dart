import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/recording_text_resource_provider.dart';
import 'form_text_key_sources.dart';

// `tomFormFieldTextKeys` against the forms themselves.
//
// The fields read their texts through getters at build time (`labelText`,
// `hintText`, ...), the list forms and toolbars in their constructors, and
// `TomField` reads `validators` the first time the validators are needed. So
// the catalogue is held to the code two ways:
//
// - From the sources: every literal `TomCtr.text*(basePath, '<key>')` read
//   (and `_childKey(basePath, '<child>')` reads, as `<child>.<key>`) of a
//   class, its mixins and every class it extends. This sees every class,
//   whether or not a test can build it, and reads outside construction.
// - By recording: the fields `TomFormFieldFamily` builds, in both families,
//   and the text inputs the factory has no method for, are pumped with a
//   resource provider that records each key asked for. What a field asks
//   for must be in the catalogue, and asked as an optional text: no form key
//   shows a dotted key when its resource is missing. A shared caption it
//   asks for under its path (`<path>.form.choose`) must be in the key table
//   of `TomFormLabels` or `TomFileLabels` instead.

const _first = Duration(days: 365 * 4);

enum _Priority { low, high }

TomSelectableSource<_Priority> _prioritySource() =>
    TomStaticSelectableSource<_Priority>(const [
      TomSelectableItem(value: _Priority.low, label: 'Low'),
      TomSelectableItem(value: _Priority.high, label: 'High'),
    ]);

TomSelectableSource<String> _citySource() =>
    TomStaticSelectableSource<String>(const [
      TomSelectableItem(value: 'oslo', label: 'Oslo'),
      TomSelectableItem(value: 'lima', label: 'Lima'),
    ]);

final DateTime _from = DateTime(2020);
final DateTime _to = _from.add(_first * 2);

/// Every factory method of [TomFormFieldFamily], each building a field with
/// the `tomId` `f`.
final List<TomField<dynamic> Function(TomFormFieldFamily)> _familyFields = [
  (f) => f.stringInput('f', 'Ada'),
  (f) => f.intInput('f', 30),
  (f) => f.doubleInput('f', 1.5),
  (f) => f.boolSwitch('f', false),
  (f) => f.boolToggle('f', false),
  (f) => f.nullableBoolToggle('f', null),
  (f) =>
      f.datePicker('f', DateTime(2024, 3, 4), firstDate: _from, lastDate: _to),
  (f) => f.timePicker('f', const TimeOfDay(hour: 9, minute: 0)),
  (f) => f.dateTimePicker(
    'f',
    DateTime(2024, 3, 4, 9, 30),
    firstDate: _from,
    lastDate: _to,
  ),
  (f) => f.dateRangePicker(
    'f',
    DateTimeRange(start: DateTime(2024, 3, 4), end: DateTime(2024, 3, 8)),
    firstDate: _from,
    lastDate: _to,
  ),
  (f) => f.durationPicker('f', const Duration(minutes: 30)),
  (f) => f.enumPicker<_Priority>('f', _Priority.low, source: _prioritySource()),
  (f) =>
      f.enumSegmented<_Priority>('f', _Priority.low, source: _prioritySource()),
  (f) => f.objectPicker<String>('f', 'oslo', source: _citySource()),
  (f) => f.searchInput<String>('f', 'oslo', source: _citySource()),
  (f) => f.lookup<String>('f', 'oslo', source: _citySource()),
  (f) => f.nStringInput('f', null),
  (f) => f.nIntInput('f', null),
  (f) => f.nDoubleInput('f', null),
  (f) => f.nDateInput('f', null, firstDate: _from, lastDate: _to),
  (f) => f.stringPicker('f', 'oslo', source: _citySource()),
  (f) => f.stringSegmented('f', 'oslo', source: _citySource()),
  (f) => f.stringMultiSelect('f', const ['oslo'], source: _citySource()),
  (f) => f.currencyInput('f', 9.99, currencyCode: 'EUR'),
];

/// Fields the factory has no method for whose texts differ from the rest.
final List<TomField<dynamic> Function()> _materialFields = [
  () => TomFormDateTextInput(
    'f',
    DateTime(2024),
    firstDate: _from,
    lastDate: _to,
  ),
  () => TomFormTimeTextInput('f', const TimeOfDay(hour: 9, minute: 0)),
  () => TomFormDateTimeTextInput(
    'f',
    DateTime(2024),
    firstDate: _from,
    lastDate: _to,
  ),
  () => TomTextFormFieldBase<String>('f', ''),
];

Widget _shell(bool cupertino, Widget child) => cupertino
    ? CupertinoApp(
        home: CupertinoPageScaffold(child: Center(child: child)),
      )
    : MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

/// A shared caption (`form.cancel`, `file.choose`) asked under a field's
/// path: the field tier of [TomFormLabels] and `TomFileLabels`, whose keys are
/// listed on those classes, not per field.
final _sharedCaption = RegExp(r'^(?:form|file)\.');

String _typeName(Object o) =>
    o.runtimeType.toString().replaceAll(RegExp(r'<.*$'), '');

void main() {
  final sources = FormTextKeySources.scan();

  test('ftk-01: the catalogue lists every concrete field class, and every '
      'other form class that reads a key of its own', () {
    final expected = {
      for (final name in sources.concreteClasses)
        if (sources.isField(name) || sources.keysOf(name).isNotEmpty) name,
    };
    expect(tomFormFieldTextKeys.keys.toSet(), expected);
    // What stops the comparison passing on a scan that found nothing.
    expect(expected, containsAll(['TomFormStringInput', 'TomListFormToolbar']));
    expect(expected.where(sources.isField).length, greaterThan(60));
  });

  test('ftk-02: each class reads in its sources exactly the keys the '
      'catalogue gives it', () {
    final wrong = <String>[];
    for (final entry in tomFormFieldTextKeys.entries) {
      final listed = {for (final k in entry.value) k.suffix};
      final read = sources.keysOf(entry.key);
      if (listed.length != read.length || !listed.containsAll(read)) {
        wrong.add(
          '${entry.key}: read ${read.toList()..sort()}, '
          'listed ${listed.toList()..sort()}',
        );
      }
    }
    expect(wrong, isEmpty);
  });

  // The shared captions' keys, from the key tables in the dartdoc of
  // `TomFormLabels` and `TomFileLabels`.
  final sharedCaptions = {
    for (final file in [
      'lib/src/forms/tom_form_labels.dart',
      'lib/src/forms/files/tom_file_labels.dart',
    ])
      for (final m in RegExp(
        r'^/// \| `((?:form|file)\.\w+)` \|',
        multiLine: true,
      ).allMatches(File(file).readAsStringSync()))
        m.group(1)!,
  };

  testWidgets('ftk-03: what a built field asks for is in the catalogue, as '
      'an optional text', (tester) async {
    final builds = <(bool, TomField<dynamic> Function())>[
      for (final cupertino in [false, true])
        for (final build in _familyFields)
          (
            cupertino,
            () => build(
              cupertino
                  ? TomFormFieldFamily.cupertino
                  : TomFormFieldFamily.material,
            ),
          ),
      for (final build in _materialFields) (false, build),
    ];
    final wrong = <String>[];
    final seen = <String>{};
    for (final (cupertino, build) in builds) {
      final provider = RecordingTextResourceProvider();
      TomTextResourceProvider.setAppResourceProvider(provider);
      final field = build();
      await tester.pumpWidget(_shell(cupertino, field.widget));
      field.validators;
      final name = _typeName(field);
      seen.add(name);
      final listed = tomFormFieldTextKeys[name];
      if (listed == null) {
        wrong.add('$name: not in the catalogue');
        continue;
      }
      final asked = provider.textKeysUnder(field.basePath);
      for (final MapEntry(key: suffix, value: required) in asked.entries) {
        if (_sharedCaption.hasMatch(suffix)) {
          // A shared caption's field tier, listed on its labels class.
          if (!sharedCaptions.contains(suffix)) {
            wrong.add('$name.$suffix: not in the key table of its labels');
          }
          continue;
        }
        if (!listed.any((k) => k.suffix == suffix)) {
          wrong.add('$name.$suffix: asked for, not listed');
        }
        if (required) wrong.add('$name.$suffix: asked as a required text');
      }
      for (final suffix in ['label', 'validators']) {
        if (!asked.containsKey(suffix)) {
          wrong.add('$name.$suffix: listed for every field, not asked for');
        }
      }
    }
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    expect(wrong, isEmpty);
    // Both families were built, not one of them twice.
    expect(seen.where((n) => n.startsWith('TomCupertino')).length, 24);
    expect(seen.length, greaterThan(40));
  });

  test('ftk-04: every form key is optional, and the settings are the '
      'validators, the text formats and the expansion policy', () {
    for (final entry in tomFormFieldTextKeys.entries) {
      for (final key in entry.value) {
        final reason = '${entry.key}.${key.suffix}';
        expect(key.presence, TomTextKeyPresence.optional, reason: reason);
        final isSetting =
            key.suffix == 'validators' ||
            key.suffix == 'policy' ||
            key.suffix.endsWith('Format');
        expect(
          key.kind,
          isSetting ? TomTextKeyKind.setting : TomTextKeyKind.text,
          reason: reason,
        );
      }
    }
  });

  test('ftk-05: no form element reads a parameter name as a second key for '
      'the same text', () {
    const aliases = {
      'labelText',
      'hintText',
      'helperText',
      'descriptionText',
      'errorText',
    };
    for (final entry in tomFormFieldTextKeys.entries) {
      for (final key in entry.value) {
        expect(
          aliases.contains(key.suffix),
          isFalse,
          reason: '${entry.key}.${key.suffix}',
        );
      }
    }
  });

  test('ftk-06: the table in doc/forms.md is the catalogue', () {
    final doc = File('doc/forms.md').readAsStringSync();
    final start = doc.indexOf('## Text keys per field');
    final section = doc.substring(start, doc.indexOf('\n## ', start + 1));
    final row = RegExp(
      r'^\| `(Tom\w+)` \| (.*?) \| (.*?) \|$',
      multiLine: true,
    );
    String cell(Iterable<TomTextKey> keys) =>
        keys.isEmpty ? '—' : keys.map((k) => '`${k.suffix}`').join(', ');
    final expected = {
      for (final entry in tomFormFieldTextKeys.entries)
        entry.key: (
          cell(entry.value.where((k) => k.kind != TomTextKeyKind.setting)),
          cell(entry.value.where((k) => k.kind == TomTextKeyKind.setting)),
        ),
    };
    final actual = {
      for (final m in row.allMatches(section))
        m.group(1)!: (m.group(2)!, m.group(3)!),
    };
    expect(actual, expected);
  });
}
