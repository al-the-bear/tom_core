import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/decoration/tom_field_anatomy.dart';
import 'package:tom_flutter_ui/src/forms/style/tom_form_style.dart';

void main() {
  const errorOutline = OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFFD32F2F), width: 2),
  );
  const fieldOutline = OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFF000000)),
  );

  group('applyErrorVisuals — no error', () {
    test('returns decoration unchanged when hasError is false', () {
      const decoration = InputDecoration(
        hintText: 'Enter value',
        border: fieldOutline,
        enabledBorder: fieldOutline,
        errorBorder: errorOutline,
      );
      const style = TomFieldStyle(
        fieldBorder: fieldOutline,
        errorBorder: errorOutline,
        errorBorderEnabled: true,
        errorIconEnabled: true,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: false,
      );

      expect(identical(result, decoration), true);
    });
  });

  group('applyErrorVisuals — errorBorder toggle', () {
    test('swaps all state-borders to errorBorder when enabled', () {
      const decoration = InputDecoration(
        border: fieldOutline,
        enabledBorder: fieldOutline,
        focusedBorder: fieldOutline,
        disabledBorder: fieldOutline,
        errorBorder: errorOutline,
      );
      const style = TomFieldStyle(
        fieldBorder: fieldOutline,
        errorBorder: errorOutline,
        errorBorderEnabled: true,
        errorIconEnabled: false,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      expect(result.enabledBorder, errorOutline);
      expect(result.focusedBorder, errorOutline);
      expect(result.disabledBorder, errorOutline);
      expect(result.border, errorOutline);
      expect(result.suffixIcon, isNull);
    });

    test('leaves border alone when errorBorderEnabled is false', () {
      const decoration = InputDecoration(
        border: fieldOutline,
        enabledBorder: fieldOutline,
        focusedBorder: fieldOutline,
        errorBorder: errorOutline,
      );
      const style = TomFieldStyle(
        fieldBorder: fieldOutline,
        errorBorder: errorOutline,
        errorBorderEnabled: false,
        errorIconEnabled: false,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      expect(result.enabledBorder, fieldOutline);
      expect(result.focusedBorder, fieldOutline);
      expect(result.border, fieldOutline);
    });

    test('leaves border alone when style.errorBorder is null', () {
      const decoration = InputDecoration(
        border: fieldOutline,
        enabledBorder: fieldOutline,
      );
      const style = TomFieldStyle(
        fieldBorder: fieldOutline,
        errorBorderEnabled: true,
        errorIconEnabled: false,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      expect(result.enabledBorder, fieldOutline);
      expect(result.border, fieldOutline);
    });
  });

  group('applyErrorVisuals — errorIcon toggle', () {
    testWidgets('appends red error icon to trailing slot when enabled',
        (tester) async {
      const decoration = InputDecoration();
      const style = TomFieldStyle(
        errorBorderEnabled: false,
        errorIconEnabled: true,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(decoration: result)),
        ),
      );

      final iconFinder = find.byIcon(Icons.error);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, const Color(0xFFD32F2F));
    });

    testWidgets('preserves existing suffixIcon and appends error icon',
        (tester) async {
      const existing = Icon(Icons.search, key: ValueKey('search'));
      const decoration = InputDecoration(suffixIcon: existing);
      const style = TomFieldStyle(
        errorIconEnabled: true,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(decoration: result)),
        ),
      );

      expect(find.byKey(const ValueKey('search')), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    test('does not append icon when errorIconEnabled is false', () {
      const decoration = InputDecoration();
      const style = TomFieldStyle(
        errorBorderEnabled: false,
        errorIconEnabled: false,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      expect(result.suffixIcon, isNull);
    });
  });

  group('applyErrorVisuals — combined', () {
    testWidgets('applies both border swap and icon when both enabled',
        (tester) async {
      const decoration = InputDecoration(
        border: fieldOutline,
        enabledBorder: fieldOutline,
        errorBorder: errorOutline,
      );
      const style = TomFieldStyle(
        fieldBorder: fieldOutline,
        errorBorder: errorOutline,
        errorBorderEnabled: true,
        errorIconEnabled: true,
      );

      final result = applyErrorVisuals(
        decoration: decoration,
        style: style,
        hasError: true,
      );

      expect(result.enabledBorder, errorOutline);
      expect(result.focusedBorder, errorOutline);
      expect(result.border, errorOutline);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(decoration: result)),
        ),
      );
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });
}
