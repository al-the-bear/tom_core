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

  // Both classes compare by value, which is what makes
  // `TomThemeScope.updateShouldNotify` mean anything: the documented way to
  // install a theme builds it inside `build`, so every parent rebuild hands
  // the scope a freshly allocated instance. Under identity that is always a
  // change; under value equality it is one only when a field moved.
  group('theme value equality', () {
    test('TomReadonlyStyle: separate instances with equal fields match', () {
      // Deliberately not const — const instances are canonicalised, so they
      // would compare equal even under identity and prove nothing.
      final a = TomReadonlyStyle(opacity: 0.5, colorOverlay: Color(0xFF112233));
      final b = TomReadonlyStyle(opacity: 0.5, colorOverlay: Color(0xFF112233));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('TomReadonlyStyle: each field is part of the comparison', () {
      const base = TomReadonlyStyle();
      expect(base, isNot(equals(const TomReadonlyStyle(opacity: 0.5))));
      expect(base,
          isNot(equals(const TomReadonlyStyle(absorbPointers: false))));
      expect(
          base,
          isNot(equals(
              const TomReadonlyStyle(colorOverlay: Color(0xFF112233)))));
      expect(base, isNot(equals(TomReadonlyStyle(builder: _dim))));
    });

    // The one place equality is reference-based, and it is deliberate: Dart
    // gives no way to compare two closures by behaviour. It is pinned so the
    // caveat cannot be "fixed" away silently — a caller who allocates a
    // builder inside `build` gets a theme that never compares equal, which is
    // exactly the trap this group exists to close, so the dartdoc tells them
    // to hoist it.
    test('TomReadonlyStyle: builders compare by reference, not behaviour', () {
      expect(TomReadonlyStyle(builder: _dim),
          equals(TomReadonlyStyle(builder: _dim)));
      expect(TomReadonlyStyle(builder: (c) => c),
          isNot(equals(TomReadonlyStyle(builder: (c) => c))));
    });

    test('TomTheme: copyWith with no overrides equals the original', () {
      const base = TomTheme.defaultTheme;
      expect(base.copyWith(), equals(base));
      expect(base.copyWith().hashCode, equals(base.hashCode));
    });

    test('TomTheme: name and the nested style both count', () {
      const base = TomTheme(name: 'a');
      expect(base.copyWith(name: 'b'), isNot(equals(base)));
      expect(
          base.copyWith(readonlyStyle: const TomReadonlyStyle(opacity: 0.5)),
          isNot(equals(base)));
      // The nested style is compared by value too, not by identity.
      expect(
          TomTheme(name: 'a', readonlyStyle: TomReadonlyStyle(opacity: 0.5)),
          equals(
              TomTheme(name: 'a', readonlyStyle: TomReadonlyStyle(opacity: 0.5))));
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

    // What the equality is *for*. `readonlyStyleOf` is reached from
    // `TomPolicyNodeBase.buildReadonly` and `TomWidgetMixin.applyAuthState`,
    // so every read-only widget in the tree is a dependent of this scope. If
    // an unrelated ancestor rebuild notified them, a scope installed the
    // documented way would turn any ancestor `setState` into a re-render of
    // the entire read-only surface.
    //
    // The child is `const` on purpose: that is what isolates the measurement.
    // Element.updateChild short-circuits on an identical widget, so the probe
    // can only rebuild by being notified — never by being re-created.
    testWidgets('an unrelated ancestor rebuild does not reach dependents',
        (tester) async {
      _DependentProbe.builds = 0;
      late StateSetter rebuildAncestor;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuildAncestor = setState;
            // The idiom doc/theme.md documents: built inside `build`, so the
            // scope receives a freshly allocated instance every time.
            return TomThemeScope(
              theme: TomTheme.defaultTheme.copyWith(
                name: 'dimmed',
                readonlyStyle: const TomReadonlyStyle(opacity: 0.5),
              ),
              child: const _DependentProbe(),
            );
          },
        ),
      );
      expect(_DependentProbe.builds, 1);

      rebuildAncestor(() {});
      await tester.pump();
      expect(_DependentProbe.builds, 1,
          reason: 'the rebuilt theme compares equal, so the scope must not '
              'notify its dependents');
    });

    // The control for the case above. Without it, an `updateShouldNotify`
    // that always returned false would pass — and a theme change would stop
    // reaching the widgets that render it.
    testWidgets('a theme that actually differs still reaches dependents',
        (tester) async {
      _DependentProbe.builds = 0;
      var opacity = 0.5;
      late StateSetter rebuildAncestor;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuildAncestor = setState;
            return TomThemeScope(
              theme: TomTheme.defaultTheme.copyWith(
                readonlyStyle: TomReadonlyStyle(opacity: opacity),
              ),
              child: const _DependentProbe(),
            );
          },
        ),
      );
      expect(_DependentProbe.builds, 1);

      rebuildAncestor(() => opacity = 0.9);
      await tester.pump();
      expect(_DependentProbe.builds, 2);
      expect(_DependentProbe.lastStyle?.opacity, 0.9);
    });
  });
}

/// A hoisted builder, used to show that two styles naming the *same* function
/// compare equal while two equivalent inline closures do not.
Widget _dim(Widget content) => Opacity(opacity: 0.3, child: content);

/// Stands in for a read-only widget: it depends on [TomThemeScope] and counts
/// how often it is built.
///
/// A `StatelessWidget` with a `const` constructor rather than a `Builder`,
/// because a `Builder` created inside the ancestor's `build` carries a fresh
/// closure each time and would be rebuilt by the ancestor regardless of what
/// the scope decides — measuring the ancestor instead of the notification.
class _DependentProbe extends StatelessWidget {
  const _DependentProbe();

  static int builds = 0;
  static TomReadonlyStyle? lastStyle;

  @override
  Widget build(BuildContext context) {
    builds++;
    lastStyle = TomThemeScope.readonlyStyleOf(context);
    return const SizedBox();
  }
}
