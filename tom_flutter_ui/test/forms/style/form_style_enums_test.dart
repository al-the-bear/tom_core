import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('TomLabelPlacement', () {
    test('has all expected values', () {
      expect(TomLabelPlacement.values, hasLength(5));
      expect(TomLabelPlacement.values, contains(TomLabelPlacement.above));
      expect(TomLabelPlacement.values, contains(TomLabelPlacement.below));
      expect(TomLabelPlacement.values, contains(TomLabelPlacement.floating));
      expect(TomLabelPlacement.values, contains(TomLabelPlacement.inline));
      expect(TomLabelPlacement.values, contains(TomLabelPlacement.hidden));
    });
  });

  group('TomErrorPlacement', () {
    test('has all expected values', () {
      expect(TomErrorPlacement.values, hasLength(5));
      expect(TomErrorPlacement.values, contains(TomErrorPlacement.below));
      expect(TomErrorPlacement.values, contains(TomErrorPlacement.above));
      expect(TomErrorPlacement.values, contains(TomErrorPlacement.tooltip));
      expect(TomErrorPlacement.values, contains(TomErrorPlacement.both));
      expect(
        TomErrorPlacement.values,
        contains(TomErrorPlacement.replaceDescription),
      );
    });
  });

  group('TomRequiredIndicator', () {
    test('has all expected values', () {
      expect(TomRequiredIndicator.values, hasLength(4));
      expect(
        TomRequiredIndicator.values,
        contains(TomRequiredIndicator.asterisk),
      );
      expect(TomRequiredIndicator.values, contains(TomRequiredIndicator.text));
      expect(TomRequiredIndicator.values, contains(TomRequiredIndicator.none));
      expect(
        TomRequiredIndicator.values,
        contains(TomRequiredIndicator.custom),
      );
    });
  });

  group('TomDescriptionPlacement', () {
    test('has all expected values', () {
      expect(TomDescriptionPlacement.values, hasLength(3));
      expect(
        TomDescriptionPlacement.values,
        contains(TomDescriptionPlacement.below),
      );
      expect(
        TomDescriptionPlacement.values,
        contains(TomDescriptionPlacement.above),
      );
      expect(
        TomDescriptionPlacement.values,
        contains(TomDescriptionPlacement.tooltip),
      );
    });
  });

  group('TomActionIconPlacement', () {
    test('has all expected values', () {
      expect(TomActionIconPlacement.values, hasLength(3));
      expect(
        TomActionIconPlacement.values,
        contains(TomActionIconPlacement.trailing),
      );
      expect(
        TomActionIconPlacement.values,
        contains(TomActionIconPlacement.leading),
      );
      expect(
        TomActionIconPlacement.values,
        contains(TomActionIconPlacement.above),
      );
    });
  });
}
