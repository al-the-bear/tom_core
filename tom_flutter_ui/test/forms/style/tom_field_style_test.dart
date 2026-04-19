import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/style/form_style_enums.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';

void main() {
  group('TomFieldStyle — defaults', () {
    test('canonical untouched defaults', () {
      const s = TomFieldStyle();
      expect(s.labelPlacement, LabelPlacement.above);
      expect(s.errorPlacement, ErrorPlacement.below);
      expect(s.requiredIndicator, RequiredIndicator.asterisk);
      expect(s.requiredIndicatorOnHint, RequiredIndicator.none);
      expect(s.descriptionPlacement, DescriptionPlacement.below);
      expect(s.actionIconPlacement, ActionIconPlacement.trailing);
      expect(s.labelFieldGap, 4.0);
      expect(s.errorFieldGap, 4.0);
      expect(s.borderRadius, 8.0);
      expect(s.disabledOpacity, 0.5);
      expect(s.readOnlyOpacity, 0.8);
      expect(s.errorBorderEnabled, isFalse);
      expect(s.errorIconEnabled, isFalse);
      expect(s.labelFieldGapBpOverrides, isEmpty);
      expect(s.focusedBackground, isNull);
      expect(s.readOnlyBackground, isNull);
    });
  });

  group('TomFieldStyle — resolveForBp', () {
    const s = TomFieldStyle();

    test('empty overrides returns default', () {
      expect(s.resolveForBp(800, 4.0, const []), 4.0);
    });

    test('picks highest minWidth <= width', () {
      final overrides = <(double, double)>[
        (600, 8.0),
        (1200, 12.0),
        (900, 10.0),
      ];
      expect(s.resolveForBp(500, 4.0, overrides), 4.0);
      expect(s.resolveForBp(600, 4.0, overrides), 8.0);
      expect(s.resolveForBp(900, 4.0, overrides), 10.0);
      expect(s.resolveForBp(1199, 4.0, overrides), 10.0);
      expect(s.resolveForBp(1200, 4.0, overrides), 12.0);
      expect(s.resolveForBp(5000, 4.0, overrides), 12.0);
    });
  });

  group('TomFieldStyle — pickPair', () {
    const s = TomFieldStyle();

    test('over value wins atomically', () {
      final result = s.pickPair<double>(
        1000,
        6.0,
        const [(1200, 12.0)],
        4.0,
        const [(600, 8.0)],
      );
      // over value 6.0 is the default; no matching override at width=1000.
      expect(result, 6.0);
    });

    test('over value null falls back to base pair', () {
      final result = s.pickPair<double>(
        700,
        null,
        const [],
        4.0,
        const [(600, 8.0)],
      );
      expect(result, 8.0);
    });

    test('over pair uses its own overrides, not base', () {
      final result = s.pickPair<double>(
        1200,
        6.0,
        const [(1200, 12.0)],
        4.0,
        const [(600, 8.0), (1200, 100.0)],
      );
      expect(result, 12.0);
    });
  });

  group('TomFieldStyle — copyWith', () {
    test('replaces named fields only', () {
      const base = TomFieldStyle();
      final next = base.copyWith(
        labelPlacement: LabelPlacement.floating,
        borderRadius: 16.0,
      );
      expect(next.labelPlacement, LabelPlacement.floating);
      expect(next.borderRadius, 16.0);
      expect(next.labelFieldGap, base.labelFieldGap);
      expect(next.errorPlacement, base.errorPlacement);
    });
  });
}
