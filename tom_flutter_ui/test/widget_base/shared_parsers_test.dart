import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// The two parsers `TomStyleResolvers` exposes for `TomCtr`'s benefit.
///
/// `TomCtr.edgeInsets` and `TomCtr.textStyle` hold no private copies of
/// `_parseEdgeInsets` and `_parseFontWeight`. Both are single
/// implementations in `TomStyleResolvers`, reached through the resource read
/// each accessor already performed.
///
/// What is asserted here is agreement: the resource route and the direct parser
/// call must produce the same object for the same value. A duplicate that comes
/// back is unlikely to come back identical — the pair that existed had already
/// drifted, `TomCtr`'s font-weight copy accepting strictly less than its twin —
/// so a same-input-same-output property is what catches a second copy, whereas
/// testing either side alone would not.
///
/// `style_resolvers_layering_test.dart` holds the structural half of the same
/// rule: no name may be declared in both classes.
void main() {
  setUpAll(() {
    TomUIColors.adapter = TomAllColorsAdapter();
  });

  /// Installs [resources] as the app resource tree for one test.
  void install(Map<String, dynamic> resources) {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  }

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  group('TomCtr.edgeInsets agrees with parseEdgeInsets', () {
    /// Every form the parser documents, as it would appear in a bundle.
    const forms = <String, dynamic>{
      'number': 8,
      'oneElement': <dynamic>[8],
      'twoElements': <dynamic>[4, 6],
      'fourElements': <dynamic>[1, 2, 3, 4],
      'all': <String, dynamic>{'all': 5},
      'symmetric': <String, dynamic>{'horizontal': 3, 'vertical': 7},
      'perSide': <String, dynamic>{
        'left': 1,
        'top': 2,
        'right': 3,
        'bottom': 4,
      },
    };

    test('for every documented form', () {
      install({'w': forms});
      for (final entry in forms.entries) {
        expect(
          TomCtr.edgeInsets('w', entry.key),
          TomStyleResolvers.parseEdgeInsets(entry.value),
          reason:
              'the ${entry.key} form differs between the resource route '
              'and the direct parser call',
        );
      }
    });

    test('and produces the objects the form names', () {
      // Pins the agreement to actual values, so that two implementations that
      // are equally wrong could not satisfy the test above.
      install({'w': forms});
      expect(TomCtr.edgeInsets('w', 'number'), const EdgeInsets.all(8));
      expect(
        TomCtr.edgeInsets('w', 'twoElements'),
        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      );
      expect(
        TomCtr.edgeInsets('w', 'fourElements'),
        const EdgeInsets.fromLTRB(1, 2, 3, 4),
      );
      expect(
        TomCtr.edgeInsets('w', 'symmetric'),
        const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      );
    });

    test('and is tolerant of a mistyped entry on both routes', () {
      install({
        'w': {
          'bad': <dynamic>[1, 'x', 3, 4],
        },
      });
      expect(
        TomCtr.edgeInsets('w', 'bad'),
        const EdgeInsets.only(left: 1, top: 0, right: 3, bottom: 4),
      );
      expect(
        TomCtr.edgeInsets('w', 'bad'),
        TomStyleResolvers.parseEdgeInsets(<dynamic>[1, 'x', 3, 4]),
      );
    });

    test('and yields null for a value no form reads', () {
      install({
        'w': {'bad': 'eight'},
      });
      expect(TomCtr.edgeInsets('w', 'bad'), isNull);
      expect(TomStyleResolvers.parseEdgeInsets('eight'), isNull);
    });
  });

  group('TomCtr.textStyle agrees with parseFontWeight', () {
    test('it reads the named weights', () {
      install({
        'w': {
          'bold': {'fontWeight': 'bold'},
          'w300': {'fontWeight': 'w300'},
        },
      });
      expect(TomCtr.textStyle('w', 'bold')!.fontWeight, FontWeight.bold);
      expect(TomCtr.textStyle('w', 'w300')!.fontWeight, FontWeight.w300);
    });

    test('it reads the numeric weights its dartdoc advertises', () {
      // The private copy took a `String?`, and the provider's text accessor
      // yields null for an int — so `fontWeight: 400` was documented on
      // TomCtr.textStyle and reachable only through TomStyleResolvers.
      install({
        'w': {
          'numeric': {'fontWeight': 400},
          'heavy': {'fontWeight': 900},
        },
      });
      expect(TomCtr.textStyle('w', 'numeric')!.fontWeight, FontWeight.w400);
      expect(TomCtr.textStyle('w', 'heavy')!.fontWeight, FontWeight.w900);
      expect(TomStyleResolvers.parseFontWeight(400), FontWeight.w400);
    });

    test('an unrecognised weight contributes nothing', () {
      install({
        'w': {
          'only': {'fontWeight': 'heavyish'},
          'beside': {'fontWeight': 'heavyish', 'fontSize': 12},
        },
      });
      expect(TomCtr.textStyle('w', 'only'), isNull);
      expect(TomCtr.textStyle('w', 'beside')!.fontWeight, isNull);
      expect(TomCtr.textStyle('w', 'beside')!.fontSize, 12);
      expect(TomStyleResolvers.parseFontWeight('heavyish'), isNull);
    });
  });
}
