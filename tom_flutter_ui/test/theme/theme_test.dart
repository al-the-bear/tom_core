import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/theme/theme.dart';

import '../../example/theme/theme_example.dart' as example;

void main() {
  group('theme example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomStateStyle.apply', () {
    test('default wraps in AbsorbPointer over Opacity', () {
      final wrapped = TomStateStyle.readonly.apply(const Text('x'));
      expect(wrapped, isA<AbsorbPointer>());
      expect((wrapped as AbsorbPointer).child, isA<Opacity>());
      expect((wrapped.child as Opacity).opacity, 0.6);
    });

    test('opacity 1.0 omits the Opacity wrapper', () {
      const style = TomStateStyle(opacity: 1.0);
      final wrapped = style.apply(const Text('x'));
      expect(wrapped, isA<AbsorbPointer>());
      expect((wrapped as AbsorbPointer).child, isA<Text>());
    });

    test('absorbPointers false and opacity 1.0 returns content untouched', () {
      const style = TomStateStyle(opacity: 1.0, absorbPointers: false);
      const content = Text('x');
      expect(identical(style.apply(content), content), isTrue);
    });

    test('colorOverlay adds a ColorFiltered layer', () {
      const style = TomStateStyle(
        opacity: 1.0,
        absorbPointers: false,
        colorOverlay: Color(0x80FF0000),
      );
      expect(style.apply(const Text('x')), isA<ColorFiltered>());
    });

    test('builder replaces the entire default treatment', () {
      final style = TomStateStyle(
        builder: (child) => Padding(padding: EdgeInsets.zero, child: child),
      );
      expect(style.apply(const Text('x')), isA<Padding>());
    });

    // The `disabled` default composes exactly like `readonly` — one class
    // describes both states, so there is no second code path to get wrong.
    // Only the opacity differs, and that difference is the whole reason the
    // two are separate values.
    test('the disabled default differs from readonly only in opacity', () {
      final wrapped = TomStateStyle.disabled.apply(const Text('x'));
      expect(wrapped, isA<AbsorbPointer>());
      expect((wrapped as AbsorbPointer).child, isA<Opacity>());
      expect((wrapped.child as Opacity).opacity, 0.38);
      expect(TomStateStyle.disabled.absorbPointers,
          TomStateStyle.readonly.absorbPointers);
      expect(TomStateStyle.disabled.opacity,
          isNot(TomStateStyle.readonly.opacity));
    });
  });

  group('TomTheme', () {
    test('defaults', () {
      const theme = TomTheme.defaultTheme;
      expect(theme.name, 'default');
      expect(theme.readonlyStyle.opacity, 0.6);
      expect(theme.disabledStyle.opacity, 0.38);
    });

    test('copyWith overrides only given fields', () {
      const theme = TomTheme(name: 'a');
      final copy = theme.copyWith(name: 'b');
      expect(copy.name, 'b');
      expect(copy.readonlyStyle.opacity, theme.readonlyStyle.opacity);
      expect(copy.disabledStyle.opacity, theme.disabledStyle.opacity);
      expect(theme.copyWith().name, 'a');
    });

    // The two styles are independent settings, not one setting read twice.
    test('copyWith moves each style without disturbing the other', () {
      const base = TomTheme.defaultTheme;

      final dimmerDisabled =
          base.copyWith(disabledStyle: const TomStateStyle(opacity: 0.2));
      expect(dimmerDisabled.disabledStyle.opacity, 0.2);
      expect(dimmerDisabled.readonlyStyle, base.readonlyStyle);

      final dimmerReadonly =
          base.copyWith(readonlyStyle: const TomStateStyle(opacity: 0.5));
      expect(dimmerReadonly.readonlyStyle.opacity, 0.5);
      expect(dimmerReadonly.disabledStyle, base.disabledStyle);
    });
  });

  // The single mapping from authorization state to appearance. Both
  // enforcement points come through here, which is what stops the `disabled`
  // treatment being written out twice with the number inlined in each.
  group('TomTheme.applyAuthState', () {
    const theme = TomTheme(
      readonlyStyle: TomStateStyle(opacity: 0.5),
      disabledStyle: TomStateStyle(opacity: 0.2),
    );
    const content = Text('x');

    test('full renders the content untouched', () {
      expect(
        identical(theme.applyAuthState(TomAuthState.full, () => content),
            content),
        isTrue,
      );
    });

    test('none collapses to a zero-size box', () {
      final result = theme.applyAuthState(TomAuthState.none, () => content);
      expect(result, isA<SizedBox>());
      expect((result as SizedBox).width, 0);
      expect(result.height, 0);
    });

    // Why the parameter is a callback and not a widget: a hidden widget's
    // content may be expensive, and under an authorization state that hides
    // it, it may not be constructible at all.
    test('none never builds the content', () {
      var built = 0;
      theme.applyAuthState(TomAuthState.none, () {
        built++;
        return content;
      });
      expect(built, 0);
    });

    test('read and disabled each use their own style', () {
      final read = theme.applyAuthState(TomAuthState.read, () => content);
      final disabled =
          theme.applyAuthState(TomAuthState.disabled, () => content);
      expect(((read as AbsorbPointer).child as Opacity).opacity, 0.5);
      expect(((disabled as AbsorbPointer).child as Opacity).opacity, 0.2);
    });
  });

  // Both classes compare by value, which is what makes
  // `TomThemeScope.updateShouldNotify` mean anything: the documented way to
  // install a theme builds it inside `build`, so every parent rebuild hands
  // the scope a freshly allocated instance. Under identity that is always a
  // change; under value equality it is one only when a field moved.
  group('theme value equality', () {
    test('TomStateStyle: separate instances with equal fields match', () {
      // Deliberately not const — const instances are canonicalised, so they
      // would compare equal even under identity and prove nothing.
      final a = TomStateStyle(opacity: 0.5, colorOverlay: Color(0xFF112233));
      final b = TomStateStyle(opacity: 0.5, colorOverlay: Color(0xFF112233));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('TomStateStyle: each field is part of the comparison', () {
      const base = TomStateStyle();
      expect(base, isNot(equals(const TomStateStyle(opacity: 0.5))));
      expect(base,
          isNot(equals(const TomStateStyle(absorbPointers: false))));
      expect(
          base,
          isNot(equals(
              const TomStateStyle(colorOverlay: Color(0xFF112233)))));
      expect(base, isNot(equals(TomStateStyle(builder: _dim))));
    });

    // The one place equality is reference-based, and it is deliberate: Dart
    // gives no way to compare two closures by behaviour. It is pinned so the
    // caveat cannot be "fixed" away silently — a caller who allocates a
    // builder inside `build` gets a theme that never compares equal, which is
    // exactly the trap this group exists to close, so the dartdoc tells them
    // to hoist it.
    test('TomStateStyle: builders compare by reference, not behaviour', () {
      expect(TomStateStyle(builder: _dim),
          equals(TomStateStyle(builder: _dim)));
      expect(TomStateStyle(builder: (c) => c),
          isNot(equals(TomStateStyle(builder: (c) => c))));
    });

    test('TomTheme: copyWith with no overrides equals the original', () {
      const base = TomTheme.defaultTheme;
      expect(base.copyWith(), equals(base));
      expect(base.copyWith().hashCode, equals(base.hashCode));
    });

    test('TomTheme: name and both nested styles count', () {
      const base = TomTheme(name: 'a');
      expect(base.copyWith(name: 'b'), isNot(equals(base)));
      expect(
          base.copyWith(readonlyStyle: const TomStateStyle(opacity: 0.5)),
          isNot(equals(base)));
      // Omitting `disabledStyle` from `==` would make a theme that restyles
      // only the disabled state fail to reach its dependents.
      expect(
          base.copyWith(disabledStyle: const TomStateStyle(opacity: 0.2)),
          isNot(equals(base)));
      // The nested style is compared by value too, not by identity.
      expect(
          TomTheme(name: 'a', readonlyStyle: TomStateStyle(opacity: 0.5)),
          equals(
              TomTheme(name: 'a', readonlyStyle: TomStateStyle(opacity: 0.5))));
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
    testWidgets('of and the two styleOf accessors return the scoped theme',
        (tester) async {
      late TomTheme seen;
      late TomStateStyle seenReadonly;
      late TomStateStyle seenDisabled;
      const theme = TomTheme(
        name: 'scoped',
        readonlyStyle: TomStateStyle(opacity: 0.4),
        disabledStyle: TomStateStyle(opacity: 0.2),
      );
      await tester.pumpWidget(
        TomThemeScope(
          theme: theme,
          child: Builder(
            builder: (context) {
              seen = TomThemeScope.of(context);
              seenReadonly = TomThemeScope.readonlyStyleOf(context);
              seenDisabled = TomThemeScope.disabledStyleOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.name, 'scoped');
      expect(seenReadonly.opacity, 0.4);
      expect(seenDisabled.opacity, 0.2);
    });

    testWidgets('falls back to defaults with no scope', (tester) async {
      late TomTheme seen;
      late TomStateStyle seenDisabled;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = TomThemeScope.of(context);
            seenDisabled = TomThemeScope.disabledStyleOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen.name, TomTheme.defaultTheme.name);
      expect(seenDisabled, TomStateStyle.disabled);
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
                readonlyStyle: const TomStateStyle(opacity: 0.5),
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
                readonlyStyle: TomStateStyle(opacity: opacity),
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
  static TomStateStyle? lastStyle;

  @override
  Widget build(BuildContext context) {
    builds++;
    lastStyle = TomThemeScope.readonlyStyleOf(context);
    return const SizedBox();
  }
}
