import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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
      // fieldBorder is left as the preset had it — null stays null so
      // withTheme never adds a border where none was declared.
      expect(styled.defaults.fieldBorder, isNull);
      expect(styled.defaults.focusedBackground, isNotNull);
    });

    test('withTheme preserves border variant but recolors it', () {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF00FF)),
      );
      final styled = TomFormStyle.bordered.withTheme(theme);
      expect(styled.defaults.fieldBorder, isA<OutlineInputBorder>());
      final side =
          (styled.defaults.fieldBorder! as OutlineInputBorder).borderSide;
      expect(side.color, theme.colorScheme.outline);
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

  group('TomFormStyle — resolveFieldStyle breakpoints', () {
    const style = TomFormStyle(
      defaults: TomFieldStyle(
        labelPlacement: LabelPlacement.floating,
        labelPlacementBpOverrides: [
          (400, LabelPlacement.above),
          (700, LabelPlacement.inline),
        ],
        labelStyle: TextStyle(fontSize: 11),
        labelStyleBpOverrides: [
          (400, TextStyle(fontSize: 13)),
          (700, TextStyle(fontSize: 15)),
        ],
        hintStyle: TextStyle(fontSize: 11),
        hintStyleBpOverrides: [
          (400, TextStyle(fontSize: 13)),
          (700, TextStyle(fontSize: 15)),
        ],
      ),
    );

    test('labelPlacement resolves by width', () {
      expect(style.resolveFieldStyle(null, 300).labelPlacement,
          LabelPlacement.floating);
      expect(style.resolveFieldStyle(null, 500).labelPlacement,
          LabelPlacement.above);
      expect(style.resolveFieldStyle(null, 900).labelPlacement,
          LabelPlacement.inline);
    });

    test('labelStyle and hintStyle resolve by width', () {
      expect(style.resolveFieldStyle(null, 300).labelStyle?.fontSize, 11);
      expect(style.resolveFieldStyle(null, 500).labelStyle?.fontSize, 13);
      expect(style.resolveFieldStyle(null, 900).labelStyle?.fontSize, 15);
      expect(style.resolveFieldStyle(null, 300).hintStyle?.fontSize, 11);
      expect(style.resolveFieldStyle(null, 900).hintStyle?.fontSize, 15);
    });

    test('per-widget override atomically replaces the base pair', () {
      final withOverride = style.copyWith(
        stringInputStyle: const TomStringInputStyle(
          labelPlacement: LabelPlacement.hidden,
        ),
      );
      final resolved = withOverride.resolveFieldStyle(
        withOverride.stringInputStyle,
        900,
      );
      expect(resolved.labelPlacement, LabelPlacement.hidden);
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
