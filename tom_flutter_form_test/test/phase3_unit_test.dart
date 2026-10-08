/// Unit tests for Phase 3 review fixes:
///   - TomFormIntField / TomFormDoubleField auto-prepend TomValidators.min /
///     TomValidators.max to the field's validator list when minValue /
///     maxValue is set, surfacing out-of-range typed input as a
///     TomValidationError instead of silently clamping.
///   - TomTimeOfDayRange value type is equatable / hashable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('Phase 3 — int/double validator auto-wiring', () {
    test('TomFormIntInput with min/max prepends min/max validators', () {
      final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
      // Two built-ins prepended; user list is empty.
      expect(f.validators.length, 2);
    });

    test(
      'TomFormIntInput surfaces out-of-range as TomValidationError',
      () async {
        final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
        f.set(99);
        await f.validate();
        expect(f.validationListenable.value, isA<TomValidationError>());
        expect(
          (f.validationListenable.value as TomValidationError).errorKey,
          'error.max',
        );
      },
    );

    test('TomFormIntInput in-range validates clean', () async {
      final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
      f.set(7);
      await f.validate();
      expect(f.validationListenable.value, isA<TomValidationSuccess>());
    });

    test(
      'TomFormDoubleInput surfaces under-min as TomValidationError',
      () async {
        final f = TomFormDoubleInput('p', 1.0, minValue: 0.0, maxValue: 100.0);
        f.set(-0.5);
        await f.validate();
        expect(f.validationListenable.value, isA<TomValidationError>());
        expect(
          (f.validationListenable.value as TomValidationError).errorKey,
          'error.min',
        );
      },
    );

    test('User-supplied validators run after built-in min/max', () async {
      // A custom validator that always errors so we can confirm it's in
      // the chain alongside the built-ins (built-ins go first; custom
      // surfaces only when min/max pass).
      TomValidationResult custom(int v) =>
          const TomValidationError('error.custom');
      final f = TomFormIntInput(
        'q',
        5,
        minValue: 0,
        maxValue: 10,
        validators: [custom],
      );
      expect(f.validators.length, 3);
      f.set(7);
      await f.validate();
      expect(f.validationListenable.value, isA<TomValidationError>());
      expect(
        (f.validationListenable.value as TomValidationError).errorKey,
        'error.custom',
      );
    });
  });

  group('Phase 3 — TomTimeOfDayRange value type', () {
    test('equatable + hashable', () {
      const a = TomTimeOfDayRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 17, minute: 30),
      );
      const b = TomTimeOfDayRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 17, minute: 30),
      );
      const c = TomTimeOfDayRange(
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('Phase 3 — Percent input no longer silent-clamps', () {
    test(
      'typed 150% surfaces as TomValidationError instead of clamping to 100%',
      () async {
        final f = TomFormPercentDoubleInput('discount', 0.1);
        // Simulate the _onChanged path: parse "150" → divide by 100 → 1.5.
        f.set(1.5);
        await f.validate();
        expect(f.validationListenable.value, isA<TomValidationError>());
        expect(
          (f.validationListenable.value as TomValidationError).errorKey,
          'error.max',
        );
      },
    );
  });

  group('Phase 3 — TomCurrencyFormatProfile resolves locale', () {
    test('locale-only "de_DE" maps to EUR', () {
      final p = TomCurrencyFormatProfile.resolve(locale: 'de_DE');
      expect(p.symbol, '€');
      expect(p.decimalSeparator, ',');
    });

    test('locale "en_US" maps to USD', () {
      final p = TomCurrencyFormatProfile.resolve(locale: 'en_US');
      expect(p.symbol, r'$');
    });

    test('explicit code wins over locale', () {
      final p = TomCurrencyFormatProfile.resolve(locale: 'de_DE', code: 'JPY');
      expect(p.symbol, '¥');
      expect(p.decimals, 0);
    });

    test('language-only "ja" maps to JPY when no region present', () {
      final p = TomCurrencyFormatProfile.resolve(locale: 'ja');
      expect(p.symbol, '¥');
    });

    test('unknown locale falls back to USD', () {
      final p = TomCurrencyFormatProfile.resolve(locale: 'xx_YY');
      expect(p.symbol, r'$');
    });
  });

  group('Phase 3 — Date field range assertions', () {
    test('TomFormDatePicker rejects initialValue before firstDate', () {
      expect(
        () => TomFormDatePicker(
          'd',
          DateTime(2020, 1, 1),
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2025, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('TomFormDatePicker rejects initialValue after lastDate', () {
      expect(
        () => TomFormDatePicker(
          'd',
          DateTime(2030, 1, 1),
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2025, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('TomFormDatePicker rejects firstDate after lastDate', () {
      expect(
        () => TomFormDatePicker(
          'd',
          DateTime(2024, 6, 1),
          firstDate: DateTime(2025, 1, 1),
          lastDate: DateTime(2024, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('TomFormDateRangePicker rejects range outside bounds', () {
      expect(
        () => TomFormDateRangePicker(
          'r',
          DateTimeRange(start: DateTime(2020, 1, 1), end: DateTime(2020, 6, 1)),
          firstDate: DateTime(2024, 1, 1),
          lastDate: DateTime(2025, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('In-range values construct cleanly', () {
      // Should not throw.
      TomFormDatePicker(
        'd',
        DateTime(2024, 6, 1),
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2025, 1, 1),
      );
      TomFormDateTimePicker(
        'dt',
        DateTime(2024, 6, 1, 9, 30),
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2025, 1, 1),
      );
    });
  });
}
