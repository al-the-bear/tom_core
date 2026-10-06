import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The public barrel, not `src/`, on purpose: every claim below is then made
// against the path the documentation tells consumers to import. Reaching into
// `src/theme/theme.dart` would verify the same behaviour through a path no
// consumer uses, leaving the package barrel's re-export as the one fact about
// this module with nothing behind it.
//
// It is the sole tom import here: the kernel types this file needs
// (`TomAuthState`, `TomUIStateController`) arrive through the barrel's
// `kernel_types` export, so the file compiles exactly as a consumer's would.
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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
      expect(
        TomStateStyle.disabled.absorbPointers,
        TomStateStyle.readonly.absorbPointers,
      );
      expect(
        TomStateStyle.disabled.opacity,
        isNot(TomStateStyle.readonly.opacity),
      );
    });
  });

  // Out of range used to fail in two different silent ways. Below 0.0 the
  // constructor accepted the value and Flutter's own assert inside `Opacity`
  // rejected it at render time, naming a frame in `basic.dart` that the caller
  // never wrote. Above 1.0 nothing rejected it at all: `apply` wraps only when
  // `opacity < 1.0`, so `opacity: 60` written for "60 %" produced no dimming
  // and no diagnostic, indistinguishable from the deliberate `opacity: 1.0`
  // pass-through above. The constructor assert turns both into a failure at
  // the offending literal.
  group('TomStateStyle opacity range', () {
    // The assert's main effect — rejecting a const literal at compile time —
    // is by its nature not writable in a test that must itself compile. These
    // route the value through a function so the constructor runs at runtime
    // and the assert becomes observable.
    double atRuntime(double value) => value;

    test('rejects a negative opacity at construction', () {
      expect(
        () => TomStateStyle(opacity: atRuntime(-1.0)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects an opacity above 1.0 instead of ignoring it', () {
      expect(
        () => TomStateStyle(opacity: atRuntime(5.0)),
        throwsA(isA<AssertionError>()),
      );
    });

    // Pins the bounds as inclusive: 0.0 (fully transparent) and 1.0 (the
    // documented way to opt out of dimming) are both legal settings, so the
    // range check must not be strict at either end.
    test('accepts both inclusive bounds', () {
      expect(() => TomStateStyle(opacity: atRuntime(0.0)), returnsNormally);
      expect(() => TomStateStyle(opacity: atRuntime(1.0)), returnsNormally);
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

      final dimmerDisabled = base.copyWith(
        disabledStyle: const TomStateStyle(opacity: 0.2),
      );
      expect(dimmerDisabled.disabledStyle.opacity, 0.2);
      expect(dimmerDisabled.readonlyStyle, base.readonlyStyle);

      final dimmerReadonly = base.copyWith(
        readonlyStyle: const TomStateStyle(opacity: 0.5),
      );
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
        identical(
          theme.applyAuthState(TomAuthState.full, () => content),
          content,
        ),
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
      final disabled = theme.applyAuthState(
        TomAuthState.disabled,
        () => content,
      );
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
      expect(base, isNot(equals(const TomStateStyle(absorbPointers: false))));
      expect(
        base,
        isNot(equals(const TomStateStyle(colorOverlay: Color(0xFF112233)))),
      );
      expect(base, isNot(equals(TomStateStyle(builder: _dim))));
    });

    // The one place equality is reference-based, and it is deliberate: Dart
    // gives no way to compare two closures by behaviour. It is pinned so the
    // caveat cannot be "fixed" away silently — a caller who allocates a
    // builder inside `build` gets a theme that never compares equal, which is
    // exactly the trap this group exists to close, so the dartdoc tells them
    // to hoist it.
    test('TomStateStyle: builders compare by reference, not behaviour', () {
      expect(
        TomStateStyle(builder: _dim),
        equals(TomStateStyle(builder: _dim)),
      );
      expect(
        TomStateStyle(builder: (c) => c),
        isNot(equals(TomStateStyle(builder: (c) => c))),
      );
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
        isNot(equals(base)),
      );
      // Omitting `disabledStyle` from `==` would make a theme that restyles
      // only the disabled state fail to reach its dependents.
      expect(
        base.copyWith(disabledStyle: const TomStateStyle(opacity: 0.2)),
        isNot(equals(base)),
      );
      // The nested style is compared by value too, not by identity.
      expect(
        TomTheme(name: 'a', readonlyStyle: TomStateStyle(opacity: 0.5)),
        equals(TomTheme(name: 'a', readonlyStyle: TomStateStyle(opacity: 0.5))),
      );
    });
  });

  group('TomButtonVariants', () {
    test('fromColorScheme derives variant colours from the scheme', () {
      const scheme = ColorScheme.light();
      final v = TomButtonVariants.fromColorScheme(scheme);
      expect(
        v.primary.backgroundColor?.resolve(<WidgetState>{}),
        scheme.primary,
      );
      expect(
        v.destructive.backgroundColor?.resolve(<WidgetState>{}),
        scheme.error,
      );
      expect(
        v.secondary.foregroundColor?.resolve(<WidgetState>{}),
        scheme.primary,
      );
      expect(
        v.auxiliary.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onSurfaceVariant,
      );
    });

    // `of(context)` is the form every doc snippet uses and the only one that
    // touches `Theme.of`, yet the case above reaches the same styles through
    // the other factory — leaving the ambient lookup, the half that can
    // actually resolve against the wrong scheme, with nothing behind it.
    testWidgets('of resolves against the ambient Theme', (tester) async {
      // Deliberately not `ColorScheme.light()`: sharing the default with the
      // case above would let `of` read *any* scheme and still match.
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00695C));
      late TomButtonVariants seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) {
              seen = TomButtonVariants.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        seen.primary.backgroundColor?.resolve(<WidgetState>{}),
        scheme.primary,
      );
      expect(
        seen.primary.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onPrimary,
      );
      expect(
        seen.destructive.backgroundColor?.resolve(<WidgetState>{}),
        scheme.error,
      );
      expect(
        seen.auxiliary.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onSurfaceVariant,
      );
    });

    // The documented idiom puts `of(context).primary` inside `build`, so a
    // getter that rebuilt its `ButtonStyle` on every read cost one allocation
    // per button per frame. Each variant is a pure function of the scheme the
    // instance was built from, so reading it twice must yield the very same
    // object rather than merely an equal one.
    test('each variant is computed once per instance', () {
      final v = TomButtonVariants.fromColorScheme(const ColorScheme.light());
      expect(identical(v.primary, v.primary), isTrue);
      expect(identical(v.secondary, v.secondary), isTrue);
      expect(identical(v.auxiliary, v.auxiliary), isTrue);
      expect(identical(v.destructive, v.destructive), isTrue);
    });
  });

  group('TomThemeScope', () {
    testWidgets('of and the two styleOf accessors return the scoped theme', (
      tester,
    ) async {
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
      late TomStateStyle seenReadonly;
      late TomStateStyle seenDisabled;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = TomThemeScope.of(context);
            // Both accessors, not just `disabledStyleOf`. They are separate
            // entry points, and `readonlyStyleOf` is the one the widget layer
            // calls most — leaving it out left the more-used half of the
            // fallback resting on its sibling's assertion.
            seenReadonly = TomThemeScope.readonlyStyleOf(context);
            seenDisabled = TomThemeScope.disabledStyleOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen.name, TomTheme.defaultTheme.name);
      expect(seenReadonly, TomStateStyle.readonly);
      expect(seenDisabled, TomStateStyle.disabled);
    });

    // `of` resolves through `dependOnInheritedWidgetOfExactType`, so the
    // *nearest* scope wins and a subtree can be re-themed without touching the
    // rest of the app — a dialog that dims its withheld fields harder than the
    // page behind it, say. Nothing pinned that: every other case in the suite
    // pumps exactly one scope, which cannot tell "nearest" from "any".
    testWidgets('a nested scope overrides its ancestor for its subtree only', (
      tester,
    ) async {
      late TomStateStyle outerSaw;
      late TomStateStyle innerSaw;
      late TomStateStyle innerSawDisabled;

      await tester.pumpWidget(
        TomThemeScope(
          // `disabledStyle` is set here and left unset on the inner scope, so
          // the inner lookup below can tell replacement from merging.
          theme: const TomTheme(
            readonlyStyle: TomStateStyle(opacity: 0.5),
            disabledStyle: TomStateStyle(opacity: 0.15),
          ),
          child: Builder(
            builder: (outerContext) {
              outerSaw = TomThemeScope.readonlyStyleOf(outerContext);
              return TomThemeScope(
                theme: const TomTheme(
                  readonlyStyle: TomStateStyle(opacity: 0.25),
                ),
                child: Builder(
                  builder: (innerContext) {
                    innerSaw = TomThemeScope.readonlyStyleOf(innerContext);
                    innerSawDisabled = TomThemeScope.disabledStyleOf(
                      innerContext,
                    );
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(innerSaw.opacity, 0.25);
      // The other half of "subtree only": a context between the two scopes
      // must still see the outer one. Asserting the inner alone would pass
      // just as well if the inner scope had replaced the outer for everyone.
      expect(outerSaw.opacity, 0.5);
      // Nesting replaces the whole `TomTheme`; it does not merge field by
      // field. The inner scope names no `disabledStyle`, so its subtree gets
      // the framework default rather than the outer scope's 0.15 — which is
      // why an inner scope meaning to change one state should build from
      // `TomThemeScope.of(context).copyWith(...)`.
      expect(innerSawDisabled, TomStateStyle.disabled);
      expect(innerSawDisabled.opacity, isNot(0.15));
    });

    // The scope-to-widget path is asserted elsewhere by reading the `Opacity`
    // a scoped style produces (`tom_policy_node_auth_gate_test.dart`), which
    // proves a number arrived but not that the *style* did — one field read
    // back cannot distinguish "the whole TomStateStyle reached `apply`" from
    // "something copied the opacity across". A scoped `builder` can: it
    // short-circuits the entire default treatment, so if it reaches the widget
    // the default wrappers are provably gone.
    testWidgets('a scoped builder replaces the treatment of a rendered node', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TomThemeScope(
            theme: const TomTheme(
              readonlyStyle: TomStateStyle(builder: _brandTreatment),
            ),
            child: _ButtonNode(uiStateController: _forceRead()),
          ),
        ),
      );

      expect(find.byKey(_brandKey), findsOneWidget);
      // What the builder is documented to displace. Both are what the default
      // treatment would have added, so their absence is the short-circuit
      // observed at the widget rather than inferred from `apply` in isolation.
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(AbsorbPointer), findsNothing);
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
    testWidgets('an unrelated ancestor rebuild does not reach dependents', (
      tester,
    ) async {
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
      expect(
        _DependentProbe.builds,
        1,
        reason:
            'the rebuilt theme compares equal, so the scope must not '
            'notify its dependents',
      );
    });

    // The control for the case above. Without it, an `updateShouldNotify`
    // that always returned false would pass — and a theme change would stop
    // reaching the widgets that render it.
    testWidgets('a theme that actually differs still reaches dependents', (
      tester,
    ) async {
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

  // The theme resolves a treatment from the authorization state and nothing
  // else; a widget's family does not enter into it. Describing
  // `readonlyStyle` as the treatment applied "when no per-family override
  // exists" would be wrong: that is a fallback whose alternative branch does
  // not exist. The claim below is the
  // corrected one, made executable.
  //
  // It guards the direction that actually matters. A family-sensitive lookup
  // cannot be introduced without failing here, so the documentation has to
  // move with the code instead of drifting from it a second time.
  group('one theme, every family', () {
    testWidgets('different families under one scope get one treatment', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TomThemeScope(
            theme: const TomTheme(readonlyStyle: TomStateStyle(opacity: 0.5)),
            child: Column(
              children: [
                _ButtonNode(uiStateController: _forceRead()),
                _InputNode(uiStateController: _forceRead()),
              ],
            ),
          ),
        ),
      );

      // The premise: these two really are different families. Without this
      // the test would still pass if both nodes reported the same one, and
      // would be asserting nothing.
      expect(
        tester.widget<_ButtonNode>(find.byType(_ButtonNode)).family,
        isNot(tester.widget<_InputNode>(find.byType(_InputNode)).family),
      );

      double opacityIn(Type node) => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(node),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      expect(opacityIn(_ButtonNode), closeTo(0.5, 0.001));
      expect(opacityIn(_InputNode), closeTo(0.5, 0.001));
    });
  });
}

TomUIStateController _forceRead() =>
    TomUIStateController(resolve: (_, _) => TomAuthState.read);

/// A widget of the `button` family. Content is a bare [SizedBox] so the only
/// [Opacity] beneath it is the one the theme put there.
class _ButtonNode extends TomButtonBase {
  _ButtonNode({super.uiStateController});

  @override
  Widget buildContent(BuildContext context) => const SizedBox();
}

/// A widget of the `input` family — the family whose read-only form is the
/// stock example of one that might want its own treatment.
class _InputNode extends TomInputBase {
  _InputNode({super.uiStateController});

  @override
  Widget buildContent(BuildContext context) => const SizedBox();
}

/// A hoisted builder, used to show that two styles naming the *same* function
/// compare equal while two equivalent inline closures do not.
Widget _dim(Widget content) => Opacity(opacity: 0.3, child: content);

/// Marks the output of [_brandTreatment] so a test can find it.
const _brandKey = Key('brandTreatment');

/// A read-only treatment that looks nothing like the default one.
///
/// Deliberately neither an [Opacity] nor an [AbsorbPointer]: a test can then
/// assert that *both* default wrappers are absent, which is what makes the
/// short-circuit visible at the widget rather than only inside `apply`.
Widget _brandTreatment(Widget content) =>
    ColoredBox(key: _brandKey, color: const Color(0xFF00695C), child: content);

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
