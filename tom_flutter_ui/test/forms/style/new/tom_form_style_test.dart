import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';

void main() {
  group('TomFormStyle — presets', () {
    test('material3 defaults is untouched TomFieldStyle', () {
      expect(
        TomFormStyle.material3.defaults.labelPlacement,
        LabelPlacement.above,
      );
      expect(
        TomFormStyle.material3.defaults.errorBorderEnabled,
        isFalse,
      );
      expect(TomFormStyle.material3.stringInputStyle, isNull);
    });

    test('compact has floating label + smaller gaps', () {
      expect(
        TomFormStyle.compact.defaults.labelPlacement,
        LabelPlacement.floating,
      );
      expect(TomFormStyle.compact.defaults.labelFieldGap, 2.0);
    });

    test('bordered enables error visuals + outlined borders', () {
      final b = TomFormStyle.bordered;
      expect(b.defaults.labelPlacement, LabelPlacement.floating);
      expect(b.defaults.errorBorderEnabled, isTrue);
      expect(b.defaults.errorIconEnabled, isTrue);
      expect(b.defaults.fieldBorder, isA<OutlineInputBorder>());
    });
  });

  group('TomFormStyle — withTheme preservation rule', () {
    test('replaces untouched preset values with themed ones', () {
      final theme = ThemeData.light();
      final styled = TomFormStyle.material3.withTheme(theme);
      expect(styled.defaults.labelStyle, isNotNull);
      expect(
        styled.defaults.labelStyle,
        theme.textTheme.bodyMedium,
      );
      expect(styled.defaults.fieldBorder, isA<OutlineInputBorder>());
      expect(styled.defaults.focusedBackground, isNotNull);
    });

    test('preserves user-set labelStyle across withTheme', () {
      final theme = ThemeData.light();
      const userLabel = TextStyle(fontSize: 42, fontFamily: 'Foo');
      final styled = TomFormStyle.material3
          .copyWith(defaults: const TomFieldStyle(labelStyle: userLabel))
          .withTheme(theme);
      expect(styled.defaults.labelStyle, userLabel);
      // Other untouched properties still themed.
      expect(
        styled.defaults.hintStyle,
        isNot(equals(const TomFieldStyle().hintStyle)),
      );
    });

    test('withTheme does not touch per-type sub-styles', () {
      final theme = ThemeData.light();
      final styled = TomFormStyle.material3
          .copyWith(
            stringInputStyle: const TomStringInputStyle(
              variant: StringInputVariant.bordered,
            ),
          )
          .withTheme(theme);
      expect(
        styled.stringInputStyle?.variant,
        StringInputVariant.bordered,
      );
    });
  });

  group('TomFormStyle — copyWith', () {
    test('replaces umbrella fields only', () {
      const base = TomFormStyle.material3;
      final next = base.copyWith(
        checkboxStyle: const TomCheckboxStyle(borderRadius: 12),
      );
      expect(next.checkboxStyle, isNotNull);
      expect(next.defaults, same(base.defaults));
      expect(next.stringInputStyle, isNull);
    });
  });
}
