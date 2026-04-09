import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';

void main() {
  group('TomFormStyle — defaults', () {
    test('default constructor has Material 3 defaults', () {
      const style = TomFormStyle();
      expect(style.labelPlacement, LabelPlacement.above);
      expect(style.errorPlacement, ErrorPlacement.below);
      expect(style.requiredIndicator, RequiredIndicator.asterisk);
      expect(style.descriptionPlacement, DescriptionPlacement.below);
      expect(style.actionIconPlacement, ActionIconPlacement.trailing);
      expect(style.fieldSpacing, 16.0);
      expect(style.fieldGroupSpacing, 24.0);
      expect(style.labelFieldGap, 4.0);
      expect(style.errorFieldGap, 4.0);
      expect(
        style.fieldContentPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
      expect(style.fieldBorder, isNull);
      expect(style.focusedBorder, isNull);
      expect(style.errorBorder, isNull);
      expect(style.borderRadius, 8.0);
      expect(style.groupDecoration, isNull);
      expect(style.groupPadding, const EdgeInsets.all(16));
      expect(style.labelStyle, isNull);
      expect(style.hintStyle, isNull);
      expect(style.errorStyle, isNull);
      expect(style.descriptionStyle, isNull);
      expect(style.disabledOpacity, 0.5);
      expect(style.readOnlyBackground, isNull);
    });
  });

  group('TomFormStyle — named constructors', () {
    test('material3 is the default style', () {
      expect(TomFormStyle.material3, const TomFormStyle());
    });

    test('compact has floating labels and reduced spacing', () {
      const compact = TomFormStyle.compact;
      expect(compact.labelPlacement, LabelPlacement.floating);
      expect(compact.fieldSpacing, 8.0);
      expect(compact.fieldGroupSpacing, 16.0);
      // Other properties remain at defaults
      expect(compact.errorPlacement, ErrorPlacement.below);
      expect(compact.borderRadius, 8.0);
    });
  });

  group('TomFormStyle — copyWith', () {
    test('copies all fields when specified', () {
      const original = TomFormStyle();
      final copied = original.copyWith(
        labelPlacement: LabelPlacement.floating,
        fieldSpacing: 20.0,
        borderRadius: 12.0,
        disabledOpacity: 0.3,
        readOnlyBackground: Colors.grey,
      );

      expect(copied.labelPlacement, LabelPlacement.floating);
      expect(copied.fieldSpacing, 20.0);
      expect(copied.borderRadius, 12.0);
      expect(copied.disabledOpacity, 0.3);
      expect(copied.readOnlyBackground, Colors.grey);
      // Unmodified properties remain at original
      expect(copied.errorPlacement, ErrorPlacement.below);
      expect(copied.fieldGroupSpacing, 24.0);
      expect(copied.labelFieldGap, 4.0);
    });

    test('returns equivalent when no overrides', () {
      const original = TomFormStyle();
      final copied = original.copyWith();
      expect(copied, original);
    });

    test('copyWith preserves non-null border properties', () {
      final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      );
      final original = TomFormStyle(fieldBorder: border);
      final copied = original.copyWith(fieldSpacing: 20.0);
      expect(copied.fieldBorder, border);
      expect(copied.fieldSpacing, 20.0);
    });

    test('copyWith can override typography', () {
      const labelStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
      const errorStyle = TextStyle(fontSize: 11, color: Colors.red);
      final style = const TomFormStyle().copyWith(
        labelStyle: labelStyle,
        errorStyle: errorStyle,
      );
      expect(style.labelStyle, labelStyle);
      expect(style.errorStyle, errorStyle);
      expect(style.hintStyle, isNull);
    });
  });

  group('TomFormStyle — equality', () {
    test('identical defaults are equal', () {
      const a = TomFormStyle();
      const b = TomFormStyle();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different field spacing not equal', () {
      const a = TomFormStyle(fieldSpacing: 16.0);
      const b = TomFormStyle(fieldSpacing: 20.0);
      expect(a, isNot(equals(b)));
    });

    test('material3 equals default', () {
      expect(TomFormStyle.material3, const TomFormStyle());
    });

    test('compact differs from material3', () {
      expect(TomFormStyle.compact, isNot(equals(TomFormStyle.material3)));
    });
  });

  group('TomFormStyle — fromResources', () {
    // fromResources calls TomCtr which requires resource initialization.
    // We test the factory with default resource state (returns defaults).
    test('returns defaults when no resources configured', () {
      final style = TomFormStyle.fromResources('nonexistent.path');
      expect(style.labelPlacement, LabelPlacement.above);
      expect(style.errorPlacement, ErrorPlacement.below);
      expect(style.fieldSpacing, 16.0);
      expect(style.borderRadius, 8.0);
      expect(style.disabledOpacity, 0.5);
    });
  });
}
