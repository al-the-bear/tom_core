import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// Minimal TomField subclass for testing
class _TestField<T> extends TomField<T> {
  _TestField(super.tomId, super.initialValue);

  @override
  Widget get widget => const SizedBox.shrink();
}

void main() {
  group('TomFormValidationError', () {
    test('stores errorKey and fields', () {
      final startDate = _TestField<String>('startDate', '');
      final endDate = _TestField<String>('endDate', '');
      final error = TomFormValidationError(
        errorKey: 'error.dateRange',
        fields: [startDate, endDate],
      );

      expect(error.errorKey, 'error.dateRange');
      expect(error.fields, [startDate, endDate]);
      expect(error.tomIds, ['startDate', 'endDate']);
      expect(error.params, isNull);
      expect(error.fieldErrorKeys, isNull);
    });

    test('stores params', () {
      final amount1 = _TestField<String>('amount1', '');
      final amount2 = _TestField<String>('amount2', '');
      final error = TomFormValidationError(
        errorKey: 'error.sumExceeds',
        params: {'max': 1000},
        fields: [amount1, amount2],
      );

      expect(error.params, {'max': 1000});
    });

    test('stores per-field error keys', () {
      final startDate = _TestField<String>('startDate', '');
      final endDate = _TestField<String>('endDate', '');
      final error = TomFormValidationError(
        errorKey: 'error.dateRange.invalid',
        fields: [startDate, endDate],
        fieldErrorKeys: {
          startDate: 'error.dateRange.startAfterEnd',
          endDate: 'error.dateRange.endBeforeStart',
        },
      );

      expect(error.fieldErrorKeys?[startDate], 'error.dateRange.startAfterEnd');
      expect(error.fieldErrorKeys?[endDate], 'error.dateRange.endBeforeStart');
    });

    test('toString provides readable representation', () {
      final field1 = _TestField<String>('field1', '');
      final error = TomFormValidationError(
        errorKey: 'error.test',
        fields: [field1],
      );

      expect(error.toString(), contains('error.test'));
      expect(error.toString(), contains('field1'));
    });

    test('tomIds returns field IDs from field references', () {
      final name = _TestField<String>('name', '');
      final email = _TestField<String>('email', '');
      final error = TomFormValidationError(
        errorKey: 'error.duplicate',
        fields: [name, email],
      );

      expect(error.tomIds, ['name', 'email']);
    });
  });
}
