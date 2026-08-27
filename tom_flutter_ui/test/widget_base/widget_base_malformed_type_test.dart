import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// bug §77 / tests §61(e): the JSON style/resource resolvers advertise a tolerant
// contract (doc/widget_base.md: "skip unrecognised values … rather than an
// error"), but several sites read a present map/list entry through an unchecked
// `as` cast that throws an uncaught CastError when the value is present but of
// the wrong runtime type. These tests feed present-but-wrong-type entries and
// assert the resolver degrades gracefully (skips the bad value) instead of
// throwing — i.e. a single mistyped config entry must not take down the whole
// widget build.
//
// Each case pairs the mistyped entry with a usable one, because "skips the bad
// value" is only observable next to a value that survived. A map whose *every*
// entry is unusable contributed nothing and resolves to `null` — that contract
// belongs to the parsers themselves and is asserted in
// `widget_base_resolvers_test.dart`, which also records the one parser that
// does not yet hold it: `parseEdgeInsets` answers an unreadable value with
// `EdgeInsets.zero`. The unpaired cases below (`['x']`, `{'all': 'x'}`) are
// that exception, asserted rather than omitted so that fixing it fails here
// too.

void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  group('TomStyleResolvers malformed-type tolerance (§77)', () {
    test('parseBorderRadius({all: String}) degrades instead of throwing', () {
      late BorderRadius? radius;
      expect(
          () => radius = TomStyleResolvers
              .parseBorderRadius({'all': '8', 'topRight': 6}),
          returnsNormally);
      // The wrong-typed `all` does not short-circuit the per-corner branch,
      // and contributes no rounding of its own.
      expect(radius!.topRight, const Radius.circular(6));
      expect(radius!.topLeft, Radius.zero);
    });

    test('parseBorderRadius({corner: String}) skips the bad corner', () {
      late BorderRadius? radius;
      expect(
          () => radius = TomStyleResolvers.parseBorderRadius(
              {'topLeft': 'oops', 'topRight': 6}),
          returnsNormally);
      expect(radius!.topLeft, Radius.zero);
      expect(radius!.topRight, const Radius.circular(6));
    });

    test('parseInputDecoration({filled: String}) skips filled', () {
      late InputDecoration? deco;
      expect(
          () => deco = TomStyleResolvers
              .parseInputDecoration({'filled': 'yes', 'labelText': 'Name'}),
          returnsNormally);
      expect(deco, isNotNull);
      expect(deco!.filled, isNull);
      expect(deco!.labelText, 'Name');
    });

    test('parseInputDecoration({labelText: int}) skips labelText', () {
      late InputDecoration? deco;
      expect(
          () => deco = TomStyleResolvers
              .parseInputDecoration({'labelText': 123, 'hintText': 'Type it'}),
          returnsNormally);
      expect(deco!.labelText, isNull);
      expect(deco!.hintText, 'Type it');
    });

    test('parseInputDecoration({labelStyle: String}) skips labelStyle', () {
      late InputDecoration? deco;
      expect(
          () => deco = TomStyleResolvers
              .parseInputDecoration({'labelStyle': 'bold', 'labelText': 'Name'}),
          returnsNormally);
      expect(deco!.labelStyle, isNull);
      expect(deco!.labelText, 'Name');
    });

    test('parseInputDecoration({contentPadding: {all: String}}) is tolerant',
        () {
      late InputDecoration? deco;
      expect(
          () => deco = TomStyleResolvers.parseInputDecoration({
                'contentPadding': {'all': 'x'},
              }),
          returnsNormally);
      expect(deco!.contentPadding, EdgeInsets.zero);
    });

    test('parseInputDecoration({contentPadding: [n, String, n, n]}) is tolerant',
        () {
      late InputDecoration? deco;
      expect(
          () => deco = TomStyleResolvers.parseInputDecoration({
                'contentPadding': [1, 'x', 3, 4],
              }),
          returnsNormally);
      // The single bad element is skipped (treated as 0); the rest survive.
      expect(deco!.contentPadding,
          const EdgeInsets.only(left: 1, top: 0, right: 3, bottom: 4));
    });

    test('parseEdgeInsets([String, n]) keeps the element that parsed', () {
      // The two-element form names a horizontal and a vertical inset. A bad
      // horizontal must cost the horizontal only — `['x', 2]` still names a
      // vertical inset of 2, and dropping the whole value loses it.
      late EdgeInsets? insets;
      expect(() => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2]),
          returnsNormally);
      expect(insets, const EdgeInsets.symmetric(horizontal: 0, vertical: 2));
    });

    test('parseEdgeInsets([n, String]) keeps the element that parsed', () {
      // The mirror of the case above: the survivor is in the other slot, so a
      // parser that happened to recover only element 0 could not pass both.
      late EdgeInsets? insets;
      expect(() => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>[1, 'x']),
          returnsNormally);
      expect(insets, const EdgeInsets.symmetric(horizontal: 1, vertical: 0));
    });

    test('parseEdgeInsets([String]) degrades like every other list length', () {
      // Nothing parsed, so nothing survives — but the answer is the same
      // `EdgeInsets.zero` the four-element form and the map form give for an
      // equally unreadable value, not a `null` that only this length returns.
      // See the note at the head of this file: zero-for-unreadable is the
      // parser's known deviation, and it deviates uniformly.
      late EdgeInsets? insets;
      expect(() => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>['x']),
          returnsNormally);
      expect(insets, EdgeInsets.zero);
    });

    test('parseEdgeInsets recovers the same way at every list length', () {
      // The defect this pins was an asymmetry, not a single wrong answer: the
      // four-element branch skipped a bad element while the one- and
      // two-element branches discarded the whole value. Asserting the three
      // lengths together is what states the rule — element in, element out,
      // whatever the length — so a future edit cannot restore the split by
      // touching one branch.
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>['x']),
          EdgeInsets.zero);
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2]),
          const EdgeInsets.symmetric(horizontal: 0, vertical: 2));
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2, 'y', 4]),
          const EdgeInsets.only(left: 0, top: 2, right: 0, bottom: 4));
      // A length no branch reads is still rejected outright: tolerance is for
      // elements of a recognised shape, not for the shape itself.
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>[1, 2, 3]), isNull);
    });

    test('TomCtr.edgeInsets([String, n]) keeps the element that parsed', () {
      // The resource route reaches the same parser, so the recovery must
      // survive the trip through the provider as well.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'pad': <dynamic>['x', 2],
        }),
      );
      late EdgeInsets? insets;
      expect(() => insets = TomCtr.edgeInsets('pad'), returnsNormally);
      expect(insets, const EdgeInsets.symmetric(horizontal: 0, vertical: 2));
    });

    test('parseButtonStyle({textStyle: String}) skips textStyle', () {
      late ButtonStyle? style;
      expect(
          () => style = TomStyleResolvers
              .parseButtonStyle({'textStyle': 'bold', 'elevation': 2}),
          returnsNormally);
      expect(style, isNotNull);
      expect(style!.textStyle, isNull);
      expect(style!.elevation?.resolve(<WidgetState>{}), 2);
    });

    test('parseStrutStyle({forceStrutHeight: String}) skips the flag', () {
      late StrutStyle? strut;
      expect(
          () => strut = TomStyleResolvers
              .parseStrutStyle({'forceStrutHeight': 'yes', 'fontSize': 12}),
          returnsNormally);
      expect(strut!.forceStrutHeight, isNull);
      expect(strut!.fontSize, 12);
    });

    test('parseStrutStyle({fontFamilyFallback: String}) skips the list', () {
      late StrutStyle? strut;
      expect(
          () => strut = TomStyleResolvers.parseStrutStyle(
              {'fontFamilyFallback': 'Arial', 'fontSize': 12}),
          returnsNormally);
      expect(strut!.fontFamilyFallback, isNull);
      expect(strut!.fontSize, 12);
    });

    test('TomCtr.edgeInsets({all: String}) does not throw', () {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'pad': {'all': 'x'},
        }),
      );
      late EdgeInsets? insets;
      expect(() => insets = TomCtr.edgeInsets('pad'), returnsNormally);
      expect(insets, EdgeInsets.zero);
    });
  });
}
