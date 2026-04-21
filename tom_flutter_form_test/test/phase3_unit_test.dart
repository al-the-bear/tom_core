/// Unit tests for Phase 3 review fixes:
///   - TomFormIntField / TomFormDoubleField auto-prepend Validators.min /
///     Validators.max to the field's validator list when minValue /
///     maxValue is set, surfacing out-of-range typed input as a
///     ValidationError instead of silently clamping.
///   - TimeRange value type is equatable / hashable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('Phase 3 — int/double validator auto-wiring', () {
    test('TomFormIntInput with min/max prepends min/max validators', () {
      final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
      // Two built-ins prepended; user list is empty.
      expect(f.validators.length, 2);
    });

    test('TomFormIntInput surfaces out-of-range as ValidationError', () async {
      final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
      f.set(99);
      await f.validate();
      expect(f.validationListenable.value, isA<ValidationError>());
      expect((f.validationListenable.value as ValidationError).errorKey,
          'error.max');
    });

    test('TomFormIntInput in-range validates clean', () async {
      final f = TomFormIntInput('q', 5, minValue: 0, maxValue: 10);
      f.set(7);
      await f.validate();
      expect(f.validationListenable.value, isA<ValidationSuccess>());
    });

    test('TomFormDoubleInput surfaces under-min as ValidationError', () async {
      final f = TomFormDoubleInput('p', 1.0, minValue: 0.0, maxValue: 100.0);
      f.set(-0.5);
      await f.validate();
      expect(f.validationListenable.value, isA<ValidationError>());
      expect((f.validationListenable.value as ValidationError).errorKey,
          'error.min');
    });

    test('User-supplied validators run after built-in min/max', () async {
      // A custom validator that always errors so we can confirm it's in
      // the chain alongside the built-ins (built-ins go first; custom
      // surfaces only when min/max pass).
      final custom =
          (int v) => const ValidationError('error.custom') as ValidationResult;
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
      expect(f.validationListenable.value, isA<ValidationError>());
      expect((f.validationListenable.value as ValidationError).errorKey,
          'error.custom');
    });
  });

  group('Phase 3 — TimeRange value type', () {
    test('equatable + hashable', () {
      const a = TimeRange(TimeOfDay(hour: 9, minute: 0),
          TimeOfDay(hour: 17, minute: 30));
      const b = TimeRange(TimeOfDay(hour: 9, minute: 0),
          TimeOfDay(hour: 17, minute: 30));
      const c = TimeRange(TimeOfDay(hour: 9, minute: 0),
          TimeOfDay(hour: 18, minute: 0));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
