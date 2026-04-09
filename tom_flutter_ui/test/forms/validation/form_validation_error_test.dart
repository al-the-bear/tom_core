import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/validation/form_validation_error.dart';

void main() {
  group('FormValidationError', () {
    test('stores errorKey and fields', () {
      const error = FormValidationError(
        errorKey: 'error.dateRange',
        fields: ['startDate', 'endDate'],
      );

      expect(error.errorKey, 'error.dateRange');
      expect(error.fields, ['startDate', 'endDate']);
      expect(error.params, isNull);
      expect(error.fieldErrorKeys, isNull);
    });

    test('stores params', () {
      const error = FormValidationError(
        errorKey: 'error.sumExceeds',
        params: {'max': 1000},
        fields: ['amount1', 'amount2'],
      );

      expect(error.params, {'max': 1000});
    });

    test('stores per-field error keys', () {
      const error = FormValidationError(
        errorKey: 'error.dateRange.invalid',
        fields: ['startDate', 'endDate'],
        fieldErrorKeys: {
          'startDate': 'error.dateRange.startAfterEnd',
          'endDate': 'error.dateRange.endBeforeStart',
        },
      );

      expect(error.fieldErrorKeys?['startDate'], 'error.dateRange.startAfterEnd');
      expect(error.fieldErrorKeys?['endDate'], 'error.dateRange.endBeforeStart');
    });

    test('toString provides readable representation', () {
      const error = FormValidationError(
        errorKey: 'error.test',
        fields: ['field1'],
      );

      expect(error.toString(), contains('error.test'));
      expect(error.toString(), contains('field1'));
    });
  });
}
