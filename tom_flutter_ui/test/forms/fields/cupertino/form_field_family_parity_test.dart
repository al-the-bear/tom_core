/// TCCA17 — Material / Cupertino parity.
///
/// `FormFieldFamily` promises that a single field declaration resolves to
/// either presentation. That promise is only worth anything if the two sides
/// behave identically below the pixels — otherwise swapping the family at a
/// breakpoint silently changes what the form *does*, not just how it looks.
///
/// So this file does not test the families separately. It declares one case
/// per factory method and runs the *same* body against both, asserting the
/// value contract (`get` / `setValue` / `isDirty` / `commit` / `reset`), the
/// authorization contract, and that each side actually mounts. A divergence
/// shows up as one half of a pair failing, which names the culprit precisely.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_bool_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_date_time_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_enum_object_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_nullable_inputs.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_numeric_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_search_lookup_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_string_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/cupertino/tom_cupertino_form_string_list_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_bool_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_date_time_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_double_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_duration_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_enum_object_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_int_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_nullable_bool_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_nullable_inputs.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_search_lookup_fields.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_string_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_string_list_field.dart';
import 'package:tom_flutter_ui/src/forms/fields/tom_form_string_selection.dart';
import 'package:tom_flutter_ui/src/forms/form_field_family.dart';
import 'package:tom_flutter_ui/src/forms/selection/static_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/selection/tom_selectable_source.dart';
import 'package:tom_flutter_ui/src/forms/tom_form.dart';
import 'package:tom_flutter_ui/src/forms/validation/validation_result.dart';
import 'package:tom_flutter_ui/src/forms/validation/validators.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _shell(FormFieldFamily family, Widget child) => family.isCupertino
    ? CupertinoApp(home: CupertinoPageScaffold(child: Center(child: child)))
    : MaterialApp(home: Scaffold(body: Center(child: child)));

/// One factory method of [FormFieldFamily], reduced to the four things the
/// shared body needs: how to build it, how to move its value, and which
/// concrete each family is expected to produce.
///
/// The generics are erased behind [build] / [mutate] closures so a single
/// list can hold cases of different value types while each case stays
/// type-checked at its own declaration site.
class _Case {
  _Case._({
    required this.name,
    required this.build,
    required this.mutate,
    required this.materialType,
    required this.cupertinoType,
    required this.sharedBase,
  });

  final String name;
  final TomField<dynamic> Function(FormFieldFamily family) build;

  /// Moves the field to a value different from its initial one.
  final void Function(TomField<dynamic> field) mutate;

  final Type materialType;
  final Type cupertinoType;

  /// Asserts the field is an instance of the abstract type both families
  /// share — the whole point of the factory.
  final void Function(TomField<dynamic> field) sharedBase;

  Type expected(FormFieldFamily f) => f.isCupertino ? cupertinoType : materialType;
}

/// Builds a [_Case] while keeping `T` visible to the value closure, so
/// `nextValue` cannot be handed a value of the wrong type.
_Case _case<T>(
  String name, {
  required TomField<T> Function(FormFieldFamily family) build,
  required T Function(TomField<T> field) nextValue,
  required Type material,
  required Type cupertino,
  required void Function(TomField<T> field) sharedBase,
}) =>
    _Case._(
      name: name,
      build: build,
      mutate: (f) {
        final typed = f as TomField<T>;
        typed.setValue(nextValue(typed));
      },
      materialType: material,
      cupertinoType: cupertino,
      sharedBase: (f) => sharedBase(f as TomField<T>),
    );

// ---------------------------------------------------------------------------
// Fixtures for the selection-backed cases
// ---------------------------------------------------------------------------

enum Priority { low, high }

TomSelectableSource<Priority> _prioritySource() =>
    StaticSelectableSource<Priority>(const [
      SelectableItem(value: Priority.low, label: 'Low'),
      SelectableItem(value: Priority.high, label: 'High'),
    ]);

TomSelectableSource<String> _citySource() =>
    StaticSelectableSource<String>(const [
      SelectableItem(value: 'oslo', label: 'Oslo'),
      SelectableItem(value: 'lima', label: 'Lima'),
    ]);

final DateTime _first = DateTime(2020);
final DateTime _last = DateTime(2030);

List<_Case> _cases() => [
      _case<String>(
        'stringInput',
        build: (f) => f.stringInput('name', 'Ada'),
        nextValue: (_) => 'Grace',
        material: TomFormStringInput,
        cupertino: TomCupertinoFormStringInput,
        sharedBase: (f) => expect(f, isA<TomFormStringField>()),
      ),
      _case<int>(
        'intInput',
        build: (f) => f.intInput('age', 30),
        nextValue: (_) => 41,
        material: TomFormIntInput,
        cupertino: TomCupertinoFormIntInput,
        sharedBase: (f) => expect(f, isA<TomFormIntField>()),
      ),
      _case<double>(
        'doubleInput',
        build: (f) => f.doubleInput('ratio', 1.5),
        nextValue: (_) => 2.25,
        material: TomFormDoubleInput,
        cupertino: TomCupertinoFormDoubleInput,
        sharedBase: (f) => expect(f, isA<TomFormDoubleField>()),
      ),
      _case<bool>(
        'boolSwitch',
        build: (f) => f.boolSwitch('active', false),
        nextValue: (_) => true,
        material: TomFormBoolSwitch,
        cupertino: TomCupertinoFormBoolSwitch,
        sharedBase: (f) => expect(f, isA<TomFormBoolField>()),
      ),
      _case<bool?>(
        'nullableBoolToggle',
        build: (f) => f.nullableBoolToggle('answer', null),
        nextValue: (_) => true,
        material: TomFormNullableBoolCheckbox,
        cupertino: TomCupertinoFormNullableBoolToggle,
        sharedBase: (f) => expect(f, isA<TomFormNullableBoolField>()),
      ),
      _case<DateTime>(
        'datePicker',
        build: (f) => f.datePicker(
          'due',
          DateTime(2024, 3, 4),
          firstDate: _first,
          lastDate: _last,
        ),
        nextValue: (_) => DateTime(2025, 6, 7),
        material: TomFormDatePicker,
        cupertino: TomCupertinoFormDatePicker,
        sharedBase: (f) => expect(f, isA<TomFormDateField>()),
      ),
      _case<TimeOfDay>(
        'timePicker',
        build: (f) => f.timePicker('at', const TimeOfDay(hour: 9, minute: 0)),
        nextValue: (_) => const TimeOfDay(hour: 17, minute: 30),
        material: TomFormTimePicker,
        cupertino: TomCupertinoFormTimePicker,
        sharedBase: (f) => expect(f, isA<TomFormTimeField>()),
      ),
      _case<Priority>(
        'enumPicker',
        build: (f) =>
            f.enumPicker<Priority>('prio', Priority.low, source: _prioritySource()),
        nextValue: (_) => Priority.high,
        material: TomFormEnumDropdown<Priority>,
        cupertino: TomCupertinoFormEnumPicker<Priority>,
        sharedBase: (f) => expect(f, isA<TomFormEnumField<Priority>>()),
      ),
      _case<String>(
        'objectPicker',
        build: (f) => f.objectPicker<String>('city', 'oslo', source: _citySource()),
        nextValue: (_) => 'lima',
        material: TomFormObjectDropdown<String>,
        cupertino: TomCupertinoFormObjectPicker<String>,
        sharedBase: (f) => expect(f, isA<TomFormObjectField<String>>()),
      ),
      _case<String>(
        'searchInput',
        build: (f) => f.searchInput<String>('city', 'oslo', source: _citySource()),
        nextValue: (_) => 'lima',
        material: TomFormSearchInput<String>,
        cupertino: TomCupertinoFormSearchInput<String>,
        sharedBase: (f) => expect(f, isA<TomFormSearchField<String>>()),
      ),
      _case<String>(
        'lookup',
        build: (f) => f.lookup<String>('city', 'oslo', source: _citySource()),
        nextValue: (_) => 'lima',
        material: TomFormLookupDialog<String>,
        cupertino: TomCupertinoFormLookupSheet<String>,
        sharedBase: (f) => expect(f, isA<TomFormLookupField<String>>()),
      ),
      _case<String?>(
        'nStringInput',
        build: (f) => f.nStringInput('note', null),
        nextValue: (_) => 'hello',
        material: TomFormNStringInput,
        cupertino: TomCupertinoFormNStringInput,
        sharedBase: (f) => expect(f, isA<TomField<String?>>()),
      ),
      _case<int?>(
        'nIntInput',
        build: (f) => f.nIntInput('count', null),
        nextValue: (_) => 7,
        material: TomFormNIntInput,
        cupertino: TomCupertinoFormNIntInput,
        sharedBase: (f) => expect(f, isA<TomField<int?>>()),
      ),
      _case<double?>(
        'nDoubleInput',
        build: (f) => f.nDoubleInput('score', null),
        nextValue: (_) => 3.5,
        material: TomFormNDoubleInput,
        cupertino: TomCupertinoFormNDoubleInput,
        sharedBase: (f) => expect(f, isA<TomField<double?>>()),
      ),
      _case<DateTime?>(
        'nDateInput',
        build: (f) => f.nDateInput(
          'seen',
          null,
          firstDate: _first,
          lastDate: _last,
        ),
        nextValue: (_) => DateTime(2026, 1, 1),
        material: TomFormNDateInput,
        cupertino: TomCupertinoFormNDateInput,
        sharedBase: (f) => expect(f, isA<TomField<DateTime?>>()),
      ),
      _case<String>(
        'stringPicker',
        build: (f) => f.stringPicker('city', 'oslo', source: _citySource()),
        nextValue: (_) => 'lima',
        material: TomFormStringDropdown,
        cupertino: TomCupertinoFormStringPicker,
        sharedBase: (f) => expect(f, isA<TomFormStringField>()),
      ),
      _case<String>(
        'stringSegmented',
        build: (f) => f.stringSegmented('city', 'oslo', source: _citySource()),
        nextValue: (_) => 'lima',
        material: TomFormStringSegmented,
        cupertino: TomCupertinoFormStringSegmented,
        sharedBase: (f) => expect(f, isA<TomFormStringField>()),
      ),
      _case<List<String>>(
        'stringMultiSelect',
        build: (f) =>
            f.stringMultiSelect('cities', const ['oslo'], source: _citySource()),
        nextValue: (_) => const ['lima'],
        material: TomFormStringFilterChips,
        cupertino: TomCupertinoFormStringListCheckedPicker,
        sharedBase: (f) => expect(f, isA<TomFormStringListField>()),
      ),
      _case<double>(
        'currencyInput',
        build: (f) => f.currencyInput('price', 9.99, currencyCode: 'EUR'),
        nextValue: (_) => 19.5,
        material: TomFormCurrencyDoubleInput,
        cupertino: TomCupertinoFormCurrencyDoubleInput,
        sharedBase: (f) => expect(f, isA<TomFormDoubleField>()),
      ),
      _case<bool>(
        'boolToggle',
        build: (f) => f.boolToggle('active', false),
        nextValue: (_) => true,
        material: TomFormBoolToggle,
        cupertino: TomCupertinoFormBoolToggle,
        sharedBase: (f) => expect(f, isA<TomFormBoolField>()),
      ),
      _case<DateTime>(
        'dateTimePicker',
        build: (f) => f.dateTimePicker(
          'startsAt',
          DateTime(2024, 3, 4, 9, 30),
          firstDate: _first,
          lastDate: _last,
        ),
        nextValue: (_) => DateTime(2025, 6, 7, 17, 45),
        material: TomFormDateTimePicker,
        cupertino: TomCupertinoFormDateTimePicker,
        sharedBase: (f) => expect(f, isA<TomFormDateTimeField>()),
      ),
      _case<DateTimeRange>(
        'dateRangePicker',
        build: (f) => f.dateRangePicker(
          'span',
          DateTimeRange(start: DateTime(2024, 3, 4), end: DateTime(2024, 3, 8)),
          firstDate: _first,
          lastDate: _last,
        ),
        nextValue: (_) => DateTimeRange(
          start: DateTime(2025, 1, 1),
          end: DateTime(2025, 1, 9),
        ),
        material: TomFormDateRangePicker,
        cupertino: TomCupertinoFormDateRangePicker,
        sharedBase: (f) => expect(f, isA<TomFormDateRangeField>()),
      ),
      _case<Duration>(
        'durationPicker',
        build: (f) => f.durationPicker('takes', const Duration(minutes: 30)),
        nextValue: (_) => const Duration(hours: 2, minutes: 15),
        material: TomFormDurationInput,
        cupertino: TomCupertinoFormDurationPicker,
        sharedBase: (f) => expect(f, isA<TomFormDurationField>()),
      ),
      _case<Priority>(
        'enumSegmented',
        build: (f) => f.enumSegmented<Priority>(
          'prio',
          Priority.low,
          source: _prioritySource(),
        ),
        nextValue: (_) => Priority.high,
        material: TomFormEnumSegmented<Priority>,
        cupertino: TomCupertinoFormEnumSegmented<Priority>,
        sharedBase: (f) => expect(f, isA<TomFormEnumField<Priority>>()),
      ),
    ];

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from({}),
    );
  });

  for (final family in const [
    FormFieldFamily.material,
    FormFieldFamily.cupertino,
  ]) {
    final label = family.isCupertino ? 'cupertino' : 'material';

    group('FormFieldFamily.$label', () {
      for (final c in _cases()) {
        group(c.name, () {
          test('resolves to the $label concrete behind the shared base', () {
            final field = c.build(family);
            expect(field.runtimeType, c.expected(family));
            c.sharedBase(field);
          });

          test('tracks dirtiness against the committed baseline', () {
            final field = c.build(family);
            final initial = field.get();
            expect(field.isDirty, isFalse,
                reason: 'a freshly built field is clean');

            c.mutate(field);
            expect(field.get(), isNot(initial));
            expect(field.isDirty, isTrue);

            field.reset();
            expect(field.get(), initial);
            expect(field.isDirty, isFalse);

            c.mutate(field);
            field.commit();
            expect(field.isDirty, isFalse,
                reason: 'commit moves the baseline to the current value');
            expect(field.initialValue, field.get());
            expect(field.validationState, isA<ValidationPristine>(),
                reason: 'commit clears validation — no errors after a save');
          });

          test('is editable and visible with no authorization narrowing', () {
            // The baseline the read-only cases below are measured against —
            // without it, "not editable" could mean the resolver never ran.
            final field = c.build(family);
            expect(field.isEditable, isTrue);
            expect(field.isVisible, isTrue);
          });

          testWidgets('mounts in the $label app shell', (tester) async {
            final field = c.build(family);
            await tester.pumpWidget(_shell(family, field.widget));
            await tester.pump();
            expect(tester.takeException(), isNull);
          });
        });
      }

      test('isCupertino reports the family it was constructed with', () {
        expect(family.isCupertino, label == 'cupertino');
      });
    });
  }

  // -------------------------------------------------------------------------
  // Cross-family assertions — the ones that are only meaningful as a pair.
  // -------------------------------------------------------------------------

  group('the two families are interchangeable', () {
    test('every case yields distinct concretes from a shared base', () {
      for (final c in _cases()) {
        final m = c.build(FormFieldFamily.material);
        final cup = c.build(FormFieldFamily.cupertino);
        expect(m.runtimeType, isNot(cup.runtimeType),
            reason: '${c.name}: the families must not collapse to one class');
        c.sharedBase(m);
        c.sharedBase(cup);
      }
    });

    test('both families start from the same value', () {
      for (final c in _cases()) {
        expect(
          c.build(FormFieldFamily.material).get(),
          c.build(FormFieldFamily.cupertino).get(),
          reason: '${c.name}: initial value must not depend on presentation',
        );
      }
    });

    test('both families derive the same basePath', () {
      for (final c in _cases()) {
        expect(
          c.build(FormFieldFamily.material).basePath,
          c.build(FormFieldFamily.cupertino).basePath,
          reason: '${c.name}: a resource bundle must serve both families',
        );
      }
    });

    test('validators run identically on both sides', () async {
      for (final family in const [
        FormFieldFamily.material,
        FormFieldFamily.cupertino,
      ]) {
        final field = family.stringInput(
          'name',
          '',
          validators: [Validators.required()],
        );
        expect(await field.validate(), isA<ValidationError>(),
            reason: 'an empty required field is invalid in either family');

        field.setValue('Ada');
        expect(await field.validate(), isA<ValidationSuccess>());
      }
    });

    test('a read-only controller disables the field in either family', () {
      for (final family in const [
        FormFieldFamily.material,
        FormFieldFamily.cupertino,
      ]) {
        final field = family.stringInput(
          'name',
          '',
          uiStateController:
              TomUIStateController(resolve: (_, _) => TomAuthState.read),
        );
        expect(field.isEditable, isFalse);
        expect(field.isVisible, isTrue);
      }
    });

    test('enumPickerFor labels its options from resources in either family',
        () async {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from({
          'Priority': {'low': 'Niedrig', 'high': 'Hoch'},
        }),
      );
      for (final family in const [
        FormFieldFamily.material,
        FormFieldFamily.cupertino,
      ]) {
        final field = family.enumPickerFor<Priority>(
          'prio',
          Priority.low,
          values: Priority.values,
        );
        expect(field, isA<TomFormEnumField<Priority>>());
        expect(field.get(), Priority.low);
      }
    });
  });
}
