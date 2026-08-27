import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_style_resolvers.dart';

/// The `resolve…` half of `TomStyleResolvers`, exercised through a real
/// resource tree.
///
/// Five parsers accept more than a map — `parseBorderRadius` takes a bare
/// number, `parseAlignment` and `parseScrollPhysics` and `parseVisualDensity`
/// take a name, `parseOffset` takes a two-element list — and `doc/widget_base.md`
/// advertises those forms in the resolver table, which lists each `parse…` and
/// its `resolve…` as one entry. They were reachable only by calling the parser
/// directly: every `resolve…` read `TomCtr.map`, which yields `null` for
/// anything that is not a map, so `radius: 8` in a bundle produced no radius
/// and no complaint. `radius: 8` is the first thing a resource author would
/// write.
///
/// Each case here pairs the scalar route with the direct parser call, because
/// the property being asserted is that the two agree — the resolver is meant to
/// be the parser plus a resource read, and nothing else.
///
/// The map forms are re-asserted alongside, since widening the input is only
/// correct if it took nothing away: every one of these five is called from
/// widgets across `lib/src/widgets/` (`alignment`, `physics`, `borderRadius`,
/// `visualDensity` and `offset` suffixes), all of them through the map route.
void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
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

  group('a scalar or list resource reaches its parser', () {
    test('resolveBorderRadius reads a bare number', () {
      install({'w': {'radius': 8}});
      expect(TomStyleResolvers.resolveBorderRadius('w', 'radius'),
          TomStyleResolvers.parseBorderRadius(8));
      expect(TomStyleResolvers.resolveBorderRadius('w', 'radius'),
          BorderRadius.circular(8));
    });

    test('resolveAlignment reads a name', () {
      install({'w': {'alignment': 'bottomRight'}});
      expect(TomStyleResolvers.resolveAlignment('w', 'alignment'),
          TomStyleResolvers.parseAlignment('bottomRight'));
      expect(TomStyleResolvers.resolveAlignment('w', 'alignment'),
          Alignment.bottomRight);
    });

    test('resolveOffset reads a two-element list', () {
      install({'w': {'offset': [3, 4]}});
      expect(TomStyleResolvers.resolveOffset('w', 'offset'),
          TomStyleResolvers.parseOffset([3, 4]));
      expect(TomStyleResolvers.resolveOffset('w', 'offset'),
          const Offset(3, 4));
    });

    test('resolveVisualDensity reads a name', () {
      install({'w': {'visualDensity': 'compact'}});
      expect(TomStyleResolvers.resolveVisualDensity('w', 'visualDensity'),
          TomStyleResolvers.parseVisualDensity('compact'));
      expect(TomStyleResolvers.resolveVisualDensity('w', 'visualDensity'),
          VisualDensity.compact);
    });

    test('resolveScrollPhysics reads a name', () {
      install({'w': {'physics': 'bouncing'}});
      expect(TomStyleResolvers.resolveScrollPhysics('w', 'physics'),
          isA<BouncingScrollPhysics>());
      expect(TomStyleResolvers.parseScrollPhysics('bouncing'),
          isA<BouncingScrollPhysics>());
    });
  });

  group('the map forms still resolve', () {
    test('resolveBorderRadius reads per-corner and all', () {
      install({
        'w': {
          'corners': {'topLeft': 2, 'bottomRight': 4},
          'uniform': {'all': 6},
        }
      });
      expect(TomStyleResolvers.resolveBorderRadius('w', 'corners'),
          const BorderRadius.only(
            topLeft: Radius.circular(2),
            bottomRight: Radius.circular(4),
          ));
      expect(TomStyleResolvers.resolveBorderRadius('w', 'uniform'),
          BorderRadius.circular(6));
    });

    test('resolveAlignment reads {x, y}', () {
      install({'w': {'alignment': {'x': 0.5, 'y': -0.5}}});
      expect(TomStyleResolvers.resolveAlignment('w', 'alignment'),
          const Alignment(0.5, -0.5));
    });

    test('resolveOffset reads {dx, dy}', () {
      install({'w': {'offset': {'dx': 1, 'dy': 2}}});
      expect(TomStyleResolvers.resolveOffset('w', 'offset'),
          const Offset(1, 2));
    });

    test('resolveVisualDensity reads {horizontal, vertical}', () {
      install({'w': {'d': {'horizontal': 1.0, 'vertical': 2.0}}});
      expect(TomStyleResolvers.resolveVisualDensity('w', 'd'),
          const VisualDensity(horizontal: 1.0, vertical: 2.0));
    });

    test('resolveScrollPhysics reads {type}', () {
      install({'w': {'p': {'type': 'clamping'}}});
      expect(TomStyleResolvers.resolveScrollPhysics('w', 'p'),
          isA<ClampingScrollPhysics>());
    });
  });

  group('the wrapper-key form still resolves', () {
    // Four of the five accept a map that carries the value under the property's
    // own name, so a resource can group it with siblings. Widening the input
    // must not consume that map as a value in its own right.
    test('resolveBorderRadius unwraps {radius}', () {
      install({'w': {'br': {'radius': 12}}});
      expect(TomStyleResolvers.resolveBorderRadius('w', 'br'),
          BorderRadius.circular(12));
    });

    test('resolveAlignment unwraps {alignment}', () {
      install({'w': {'a': {'alignment': 'topCenter'}}});
      expect(TomStyleResolvers.resolveAlignment('w', 'a'),
          Alignment.topCenter);
    });

    test('resolveVisualDensity unwraps {visualDensity}', () {
      install({'w': {'d': {'visualDensity': 'comfortable'}}});
      expect(TomStyleResolvers.resolveVisualDensity('w', 'd'),
          VisualDensity.comfortable);
    });

    test('resolveScrollPhysics unwraps {physics}', () {
      install({'w': {'p': {'physics': 'never'}}});
      expect(TomStyleResolvers.resolveScrollPhysics('w', 'p'),
          isA<NeverScrollableScrollPhysics>());
    });
  });

  group('an absent or unusable resource still yields null', () {
    test('a missing key resolves to null', () {
      install({'w': <String, dynamic>{}});
      expect(TomStyleResolvers.resolveBorderRadius('w', 'nope'), isNull);
      expect(TomStyleResolvers.resolveAlignment('w', 'nope'), isNull);
      expect(TomStyleResolvers.resolveOffset('w', 'nope'), isNull);
      expect(TomStyleResolvers.resolveVisualDensity('w', 'nope'), isNull);
      expect(TomStyleResolvers.resolveScrollPhysics('w', 'nope'), isNull);
    });

    test('a value of a shape no parser reads resolves to null', () {
      // Reading the raw value rather than a map widens what gets *through*, not
      // what counts as usable: the parser still has the final say.
      install({
        'w': {
          'r': 'eight',
          'a': 'diagonal',
          'o': [1, 2, 3],
          'd': 'roomy',
          'p': 'springy',
        }
      });
      expect(TomStyleResolvers.resolveBorderRadius('w', 'r'), isNull);
      expect(TomStyleResolvers.resolveAlignment('w', 'a'), isNull);
      expect(TomStyleResolvers.resolveOffset('w', 'o'), isNull);
      expect(TomStyleResolvers.resolveVisualDensity('w', 'd'), isNull);
      expect(TomStyleResolvers.resolveScrollPhysics('w', 'p'), isNull);
    });
  });

  group('the twelve map-only resolvers are unaffected', () {
    // They exist here so that "read the raw value" cannot spread to a resolver
    // whose parser only accepts a map, where it would let a scalar through to
    // a signature that cannot take one.
    test('resolveTextStyle reads its map', () {
      install({'w': {'s': {'fontSize': 14, 'fontWeight': 'bold'}}});
      final style = TomStyleResolvers.resolveTextStyle('w', 's');
      expect(style!.fontSize, 14);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('resolveTextStyle ignores a scalar resource', () {
      install({'w': {'s': 14}});
      expect(TomStyleResolvers.resolveTextStyle('w', 's'), isNull);
    });
  });
}
