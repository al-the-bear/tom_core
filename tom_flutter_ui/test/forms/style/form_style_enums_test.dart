import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';

void main() {
  group('LabelPlacement', () {
    test('has all expected values', () {
      expect(LabelPlacement.values, hasLength(5));
      expect(LabelPlacement.values, contains(LabelPlacement.above));
      expect(LabelPlacement.values, contains(LabelPlacement.below));
      expect(LabelPlacement.values, contains(LabelPlacement.floating));
      expect(LabelPlacement.values, contains(LabelPlacement.inline));
      expect(LabelPlacement.values, contains(LabelPlacement.hidden));
    });
  });

  group('ErrorPlacement', () {
    test('has all expected values', () {
      expect(ErrorPlacement.values, hasLength(5));
      expect(ErrorPlacement.values, contains(ErrorPlacement.below));
      expect(ErrorPlacement.values, contains(ErrorPlacement.above));
      expect(ErrorPlacement.values, contains(ErrorPlacement.tooltip));
      expect(ErrorPlacement.values, contains(ErrorPlacement.both));
      expect(ErrorPlacement.values, contains(ErrorPlacement.replaceDescription));
    });
  });

  group('RequiredIndicator', () {
    test('has all expected values', () {
      expect(RequiredIndicator.values, hasLength(4));
      expect(RequiredIndicator.values, contains(RequiredIndicator.asterisk));
      expect(RequiredIndicator.values, contains(RequiredIndicator.text));
      expect(RequiredIndicator.values, contains(RequiredIndicator.none));
      expect(RequiredIndicator.values, contains(RequiredIndicator.custom));
    });
  });

  group('DescriptionPlacement', () {
    test('has all expected values', () {
      expect(DescriptionPlacement.values, hasLength(3));
      expect(DescriptionPlacement.values, contains(DescriptionPlacement.below));
      expect(DescriptionPlacement.values, contains(DescriptionPlacement.above));
      expect(
        DescriptionPlacement.values,
        contains(DescriptionPlacement.tooltip),
      );
    });
  });

  group('ActionIconPlacement', () {
    test('has all expected values', () {
      expect(ActionIconPlacement.values, hasLength(3));
      expect(
        ActionIconPlacement.values,
        contains(ActionIconPlacement.trailing),
      );
      expect(
        ActionIconPlacement.values,
        contains(ActionIconPlacement.leading),
      );
      expect(ActionIconPlacement.values, contains(ActionIconPlacement.above));
    });
  });
}
