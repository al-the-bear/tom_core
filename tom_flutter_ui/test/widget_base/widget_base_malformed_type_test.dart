import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// The JSON style and resource resolvers advertise a tolerant contract
// (`doc/widget_base.md`: "skip unrecognised values … rather than an error"),
// and tolerance has to cover the entry that is present but of the *wrong
// runtime type*, not only the entry that is absent. Reading such an entry
// through an unchecked `as` cast throws a CastError out of the widget build,
// which would let one mistyped config entry take down the whole build. These
// tests feed present-but-wrong-type entries and assert that the resolver
// degrades gracefully — skips the bad value — instead of throwing.
//
// Each case pairs the mistyped entry with a usable one, because "skips the bad
// value" is only observable next to a value that survived. A map whose *every*
// entry is unusable contributed nothing and resolves to `null` — that contract
// belongs to the parsers themselves and is asserted in
// `widget_base_resolvers_test.dart`.
//
// The two rules are separate and this file keeps them apart, because collapsing
// them is how the parser went wrong in the first place. **Element tolerance**
// says a bad element costs its own slot and nothing else, so `['x', 2]` is
// still a vertical inset of 2. **Nothing-contributed** says a shape out of
// which no slot could be read is not a value at all, so `['x']` and
// `{'all': 'x'}` are `null` rather than `EdgeInsets.zero`. Answering zero
// there would be indistinguishable, to a caller writing `?? fallback`, from a
// deliberate "no padding", so `parseEdgeInsets` holds both rules at every list
// length and for the map form.

void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  group('TomStyleResolvers malformed-type tolerance', () {
    test('parseBorderRadius({all: String}) degrades instead of throwing', () {
      late BorderRadius? radius;
      expect(
        () => radius = TomStyleResolvers.parseBorderRadius({
          'all': '8',
          'topRight': 6,
        }),
        returnsNormally,
      );
      // The wrong-typed `all` does not short-circuit the per-corner branch,
      // and contributes no rounding of its own.
      expect(radius!.topRight, const Radius.circular(6));
      expect(radius!.topLeft, Radius.zero);
    });

    test('parseBorderRadius({corner: String}) skips the bad corner', () {
      late BorderRadius? radius;
      expect(
        () => radius = TomStyleResolvers.parseBorderRadius({
          'topLeft': 'oops',
          'topRight': 6,
        }),
        returnsNormally,
      );
      expect(radius!.topLeft, Radius.zero);
      expect(radius!.topRight, const Radius.circular(6));
    });

    test('parseInputDecoration({filled: String}) skips filled', () {
      late InputDecoration? deco;
      expect(
        () => deco = TomStyleResolvers.parseInputDecoration({
          'filled': 'yes',
          'labelText': 'Name',
        }),
        returnsNormally,
      );
      expect(deco, isNotNull);
      expect(deco!.filled, isNull);
      expect(deco!.labelText, 'Name');
    });

    test('parseInputDecoration({labelText: int}) skips labelText', () {
      late InputDecoration? deco;
      expect(
        () => deco = TomStyleResolvers.parseInputDecoration({
          'labelText': 123,
          'hintText': 'Type it',
        }),
        returnsNormally,
      );
      expect(deco!.labelText, isNull);
      expect(deco!.hintText, 'Type it');
    });

    test('parseInputDecoration({labelStyle: String}) skips labelStyle', () {
      late InputDecoration? deco;
      expect(
        () => deco = TomStyleResolvers.parseInputDecoration({
          'labelStyle': 'bold',
          'labelText': 'Name',
        }),
        returnsNormally,
      );
      expect(deco!.labelStyle, isNull);
      expect(deco!.labelText, 'Name');
    });

    test(
      'parseInputDecoration({contentPadding: {all: String}}) skips padding',
      () {
        // Paired with a usable key, because an unreadable `contentPadding` is now
        // absent rather than zero — and "absent" is only visible next to a
        // sibling that survived the same call.
        late InputDecoration? deco;
        expect(
          () => deco = TomStyleResolvers.parseInputDecoration({
            'contentPadding': {'all': 'x'},
            'labelText': 'Name',
          }),
          returnsNormally,
        );
        expect(
          deco!.contentPadding,
          isNull,
          reason:
              'a padding nothing could be read out of is not a padding of '
              'zero — the decoration must leave the field unset so Flutter '
              'applies its own default',
        );
        expect(deco!.labelText, 'Name');
      },
    );

    test(
      'parseInputDecoration({contentPadding: {all: String}}) alone is null',
      () {
        // The unpaired form. The nested parser now answers `null`, so the outer
        // map contributed nothing either and the whole decoration collapses —
        // which is how a caller's `?? defaultDecoration` finally reaches its
        // fallback for a decoration whose only key was a typo.
        expect(
          TomStyleResolvers.parseInputDecoration({
            'contentPadding': {'all': 'x'},
          }),
          isNull,
        );
      },
    );

    test(
      'parseInputDecoration({contentPadding: [n, String, n, n]}) is tolerant',
      () {
        late InputDecoration? deco;
        expect(
          () => deco = TomStyleResolvers.parseInputDecoration({
            'contentPadding': [1, 'x', 3, 4],
          }),
          returnsNormally,
        );
        // The single bad element is skipped (treated as 0); the rest survive.
        expect(
          deco!.contentPadding,
          const EdgeInsets.only(left: 1, top: 0, right: 3, bottom: 4),
        );
      },
    );

    test('parseEdgeInsets([String, n]) keeps the element that parsed', () {
      // The two-element form names a horizontal and a vertical inset. A bad
      // horizontal must cost the horizontal only — `['x', 2]` still names a
      // vertical inset of 2, and dropping the whole value loses it.
      late EdgeInsets? insets;
      expect(
        () => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2]),
        returnsNormally,
      );
      expect(insets, const EdgeInsets.symmetric(horizontal: 0, vertical: 2));
    });

    test('parseEdgeInsets([n, String]) keeps the element that parsed', () {
      // The mirror of the case above: the survivor is in the other slot, so a
      // parser that happened to recover only element 0 could not pass both.
      late EdgeInsets? insets;
      expect(
        () => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>[1, 'x']),
        returnsNormally,
      );
      expect(insets, const EdgeInsets.symmetric(horizontal: 1, vertical: 0));
    });

    test('parseEdgeInsets([String]) has nothing to keep, so keeps nothing', () {
      // The one-element form names a single inset and that one element did not
      // parse, so no slot was filled. Element tolerance has nothing to be
      // tolerant *of* here — there is no survivor to protect — and answering
      // `EdgeInsets.zero` would state a padding the resource never named.
      late EdgeInsets? insets;
      expect(
        () => insets = TomStyleResolvers.parseEdgeInsets(<dynamic>['x']),
        returnsNormally,
      );
      expect(insets, isNull);
    });

    test('parseEdgeInsets applies both rules at every list length', () {
      // Two rules, three lengths, asserted together because each rule was once
      // held at some lengths and not others. Element tolerance was the earlier
      // asymmetry — the four-element branch skipped a bad element while the
      // shorter ones discarded the whole value. Nothing-contributed was the
      // later one, and ran the other way: the one-element branch answered
      // `null` while the map form and the longer lists answered zero.
      //
      // Something parsed → the survivors are kept, at every length:
      expect(
        TomStyleResolvers.parseEdgeInsets(<dynamic>[2]),
        const EdgeInsets.all(2),
      );
      expect(
        TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2]),
        const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      );
      expect(
        TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 2, 'y', 4]),
        const EdgeInsets.only(left: 0, top: 2, right: 0, bottom: 4),
      );

      // Nothing parsed → no value, at every length:
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>['x']), isNull);
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>['x', 'y']), isNull);
      expect(
        TomStyleResolvers.parseEdgeInsets(<dynamic>['w', 'x', 'y', 'z']),
        isNull,
      );

      // A length no branch reads is still rejected outright: tolerance is for
      // elements of a recognised shape, not for the shape itself.
      expect(TomStyleResolvers.parseEdgeInsets(<dynamic>[1, 2, 3]), isNull);
    });

    test('parseEdgeInsets applies both rules to the map form too', () {
      // The map form has two sub-shapes — `all`, and the per-side/axis keys —
      // and the second one is where the leak lived longest: an unrecognised
      // key set produced four absent sides, which `EdgeInsets.only` renders as
      // zero on all four without anything having been read.
      expect(
        TomStyleResolvers.parseEdgeInsets({'left': 'x', 'top': 3}),
        const EdgeInsets.only(top: 3),
      );
      expect(TomStyleResolvers.parseEdgeInsets({'all': 'x'}), isNull);
      expect(TomStyleResolvers.parseEdgeInsets({'nonsense': 1}), isNull);
      expect(TomStyleResolvers.parseEdgeInsets({'left': 'x'}), isNull);
      // `all` unreadable but a side usable: the map still contributed, and the
      // side is what it contributed.
      expect(
        TomStyleResolvers.parseEdgeInsets({'all': 'x', 'bottom': 5}),
        const EdgeInsets.only(bottom: 5),
      );
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
        () => style = TomStyleResolvers.parseButtonStyle({
          'textStyle': 'bold',
          'elevation': 2,
        }),
        returnsNormally,
      );
      expect(style, isNotNull);
      expect(style!.textStyle, isNull);
      expect(style!.elevation?.resolve(<WidgetState>{}), 2);
    });

    test('parseStrutStyle({forceStrutHeight: String}) skips the flag', () {
      late StrutStyle? strut;
      expect(
        () => strut = TomStyleResolvers.parseStrutStyle({
          'forceStrutHeight': 'yes',
          'fontSize': 12,
        }),
        returnsNormally,
      );
      expect(strut!.forceStrutHeight, isNull);
      expect(strut!.fontSize, 12);
    });

    test('parseStrutStyle({fontFamilyFallback: String}) skips the list', () {
      late StrutStyle? strut;
      expect(
        () => strut = TomStyleResolvers.parseStrutStyle({
          'fontFamilyFallback': 'Arial',
          'fontSize': 12,
        }),
        returnsNormally,
      );
      expect(strut!.fontFamilyFallback, isNull);
      expect(strut!.fontSize, 12);
    });

    test('TomCtr.edgeInsets({all: String}) reports the resource as unusable', () {
      // The resource route carries the contract as well as the parsing, so a
      // caller writing `TomCtr.edgeInsets('pad') ?? defaultPadding` reaches its
      // fallback for a typo'd resource instead of rendering flush to the edge.
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(<String, dynamic>{
          'pad': {'all': 'x'},
        }),
      );
      late EdgeInsets? insets;
      expect(() => insets = TomCtr.edgeInsets('pad'), returnsNormally);
      expect(insets, isNull);
    });
  });
}
