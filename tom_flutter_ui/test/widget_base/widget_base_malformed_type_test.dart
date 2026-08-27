import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_construction_helpers.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_style_resolvers.dart';

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
// `widget_base_resolvers_test.dart`.

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
