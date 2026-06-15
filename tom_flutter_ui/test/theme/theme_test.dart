import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/theme/theme.dart';

import '../../example/theme/theme_example.dart' as example;

void main() {
  group('theme example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomReadonlyStyle.apply', () {
    test('default wraps in AbsorbPointer over Opacity', () {
      final wrapped = TomReadonlyStyle.defaultStyle.apply(const Text('x'));
      expect(wrapped, isA<AbsorbPointer>());
      expect((wrapped as AbsorbPointer).child, isA<Opacity>());
      expect((wrapped.child as Opacity).opacity, 0.6);
    });

    test('opacity 1.0 omits the Opacity wrapper', () {
      const style = TomReadonlyStyle(opacity: 1.0);
      final wrapped = style.apply(const Text('x'));
      expect(wrapped, isA<AbsorbPointer>());
      expect((wrapped as AbsorbPointer).child, isA<Text>());
    });

    test('absorbPointers false and opacity 1.0 returns content untouched', () {
      const style = TomReadonlyStyle(opacity: 1.0, absorbPointers: false);
      const content = Text('x');
      expect(identical(style.apply(content), content), isTrue);
    });

    test('colorOverlay adds a ColorFiltered layer', () {
      const style = TomReadonlyStyle(
        opacity: 1.0,
        absorbPointers: false,
        colorOverlay: Color(0x80FF0000),
      );
      expect(style.apply(const Text('x')), isA<ColorFiltered>());
    });

    test('builder replaces the entire default treatment', () {
      final style = TomReadonlyStyle(
        builder: (child) => Padding(padding: EdgeInsets.zero, child: child),
      );
      expect(style.apply(const Text('x')), isA<Padding>());
    });
  });

  group('TomTheme', () {
    test('defaults', () {
      const theme = TomTheme.defaultTheme;
      expect(theme.name, 'default');
      expect(theme.readonlyStyle.opacity, 0.6);
    });

    test('copyWith overrides only given fields', () {
      const theme = TomTheme(name: 'a');
      final copy = theme.copyWith(name: 'b');
      expect(copy.name, 'b');
      expect(copy.readonlyStyle.opacity, theme.readonlyStyle.opacity);
      expect(theme.copyWith().name, 'a');
    });
  });

  group('TomButtonVariants.fromColorScheme', () {
    test('derives variant colours from the scheme', () {
      const scheme = ColorScheme.light();
      final v = TomButtonVariants.fromColorScheme(scheme);
      expect(v.primary.backgroundColor?.resolve(<WidgetState>{}),
          scheme.primary);
      expect(v.destructive.backgroundColor?.resolve(<WidgetState>{}),
          scheme.error);
      expect(v.secondary.foregroundColor?.resolve(<WidgetState>{}),
          scheme.primary);
      expect(v.auxiliary.foregroundColor?.resolve(<WidgetState>{}),
          scheme.onSurfaceVariant);
    });
  });

  group('TomThemeScope', () {
    testWidgets('of/readonlyStyleOf return the scoped theme', (tester) async {
      late TomTheme seen;
      late TomReadonlyStyle seenStyle;
      const theme = TomTheme(
        name: 'scoped',
        readonlyStyle: TomReadonlyStyle(opacity: 0.4),
      );
      await tester.pumpWidget(
        TomThemeScope(
          theme: theme,
          child: Builder(
            builder: (context) {
              seen = TomThemeScope.of(context);
              seenStyle = TomThemeScope.readonlyStyleOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.name, 'scoped');
      expect(seenStyle.opacity, 0.4);
    });

    testWidgets('falls back to defaults with no scope', (tester) async {
      late TomTheme seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = TomThemeScope.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen.name, TomTheme.defaultTheme.name);
    });
  });
}
