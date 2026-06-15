import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_style_resolvers.dart';

import '../../example/widget_base/widget_base_example.dart' as example;

void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
  });

  tearDown(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  group('widget_base example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  group('TomStyleResolvers.parseTextStyle', () {
    test('returns null for null/empty map', () {
      expect(TomStyleResolvers.parseTextStyle(null), isNull);
      expect(TomStyleResolvers.parseTextStyle(<String, dynamic>{}), isNull);
    });

    test('parses font, colour, decoration and overflow', () {
      final style = TomStyleResolvers.parseTextStyle({
        'fontSize': 16,
        'fontWeight': 'bold',
        'fontStyle': 'italic',
        'color': '#FF0000',
        'backgroundColor': '#00FF00',
        'letterSpacing': 1.5,
        'wordSpacing': 2.0,
        'height': 1.2,
        'decoration': 'underline',
        'decorationStyle': 'dashed',
        'overflow': 'ellipsis',
      });
      expect(style, isNotNull);
      expect(style!.fontSize, 16);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.color, const Color(0xFFFF0000));
      expect(style.backgroundColor, const Color(0xFF00FF00));
      expect(style.letterSpacing, 1.5);
      expect(style.wordSpacing, 2.0);
      expect(style.height, 1.2);
      expect(style.decoration, TextDecoration.underline);
      expect(style.decorationStyle, TextDecorationStyle.dashed);
      expect(style.overflow, TextOverflow.ellipsis);
    });

    test('accepts numeric fontWeight', () {
      final style = TomStyleResolvers.parseTextStyle({'fontWeight': 700});
      expect(style!.fontWeight, FontWeight.w700);
    });
  });

  group('TomStyleResolvers.parseButtonStyle', () {
    test('returns null for empty map', () {
      expect(TomStyleResolvers.parseButtonStyle(<String, dynamic>{}), isNull);
    });

    test('wraps colours in WidgetStateProperty and parses sizes', () {
      final style = TomStyleResolvers.parseButtonStyle({
        'backgroundColor': '#123456',
        'foregroundColor': '#654321',
        'elevation': 6,
        'minimumSize': {'width': 100, 'height': 40},
        'tapTargetSize': 'shrinkWrap',
      });
      expect(style, isNotNull);
      expect(style!.backgroundColor!.resolve(<WidgetState>{}),
          const Color(0xFF123456));
      expect(style.foregroundColor!.resolve(<WidgetState>{}),
          const Color(0xFF654321));
      expect(style.elevation!.resolve(<WidgetState>{}), 6.0);
      expect(style.minimumSize!.resolve(<WidgetState>{}), const Size(100, 40));
      expect(style.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });
  });

  group('TomStyleResolvers.parseShapeBorder', () {
    test('defaults to rounded rectangle', () {
      final border = TomStyleResolvers.parseShapeBorder({'borderRadius': 8});
      expect(border, isA<RoundedRectangleBorder>());
      final radius = (border as RoundedRectangleBorder).borderRadius
          .resolve(TextDirection.ltr);
      expect(radius.topLeft.x, 8.0);
    });

    test('parses stadium / circle / beveled / continuous', () {
      expect(TomStyleResolvers.parseShapeBorder({'type': 'stadium'}),
          isA<StadiumBorder>());
      expect(TomStyleResolvers.parseShapeBorder({'type': 'circle'}),
          isA<CircleBorder>());
      expect(TomStyleResolvers.parseShapeBorder({'type': 'beveled'}),
          isA<BeveledRectangleBorder>());
      expect(TomStyleResolvers.parseShapeBorder({'type': 'continuous'}),
          isA<ContinuousRectangleBorder>());
    });
  });

  group('TomStyleResolvers.parseBorderRadius', () {
    test('uniform from number', () {
      final r = TomStyleResolvers.parseBorderRadius(10);
      expect(r, BorderRadius.circular(10));
    });

    test('all shorthand', () {
      final r = TomStyleResolvers.parseBorderRadius({'all': 6});
      expect(r, BorderRadius.circular(6));
    });

    test('per-corner', () {
      final r = TomStyleResolvers.parseBorderRadius({
        'topLeft': 1,
        'topRight': 2,
        'bottomLeft': 3,
        'bottomRight': 4,
      })!;
      expect(r.topLeft, const Radius.circular(1));
      expect(r.bottomRight, const Radius.circular(4));
    });

    test('null for unsupported value', () {
      expect(TomStyleResolvers.parseBorderRadius('nonsense'), isNull);
      expect(TomStyleResolvers.parseBorderRadius(null), isNull);
    });
  });

  group('TomStyleResolvers.parseBorderSide', () {
    test('defaults width 1.0 and black colour', () {
      final side = TomStyleResolvers.parseBorderSide({'width': 1})!;
      expect(side.width, 1.0);
      expect(side.color, const Color(0xFF000000));
      expect(side.style, BorderStyle.solid);
    });

    test('style none', () {
      final side = TomStyleResolvers.parseBorderSide({'style': 'none'})!;
      expect(side.style, BorderStyle.none);
    });
  });

  group('TomStyleResolvers.parseDecoration', () {
    test('builds a BoxDecoration with colour, radius and border', () {
      final dec = TomStyleResolvers.parseDecoration({
        'color': '#ABCDEF',
        'borderRadius': 4,
        'border': {'color': '#000000', 'width': 2},
      }) as BoxDecoration;
      expect(dec.color, const Color(0xFFABCDEF));
      expect(dec.borderRadius, BorderRadius.circular(4));
      expect(dec.border, isNotNull);
    });

    test('circle shape drops the border radius', () {
      final dec =
          TomStyleResolvers.parseDecoration({'shape': 'circle'}) as BoxDecoration;
      expect(dec.shape, BoxShape.circle);
      expect(dec.borderRadius, isNull);
    });
  });

  group('TomStyleResolvers.parseBoxConstraints', () {
    test('applies defaults for missing bounds', () {
      final c = TomStyleResolvers.parseBoxConstraints({'minWidth': 10})!;
      expect(c.minWidth, 10);
      expect(c.maxWidth, double.infinity);
      expect(c.minHeight, 0.0);
    });
  });

  group('TomStyleResolvers.parseAlignment', () {
    test('named alignments', () {
      expect(TomStyleResolvers.parseAlignment('topLeft'), Alignment.topLeft);
      expect(TomStyleResolvers.parseAlignment('center'), Alignment.center);
      expect(TomStyleResolvers.parseAlignment('bottom_right'),
          Alignment.bottomRight);
    });

    test('custom {x, y}', () {
      expect(TomStyleResolvers.parseAlignment({'x': 0.5, 'y': -0.5}),
          const Alignment(0.5, -0.5));
    });

    test('null for unknown', () {
      expect(TomStyleResolvers.parseAlignment('elsewhere'), isNull);
    });
  });

  group('TomStyleResolvers.parseOffset', () {
    test('map and list forms', () {
      expect(TomStyleResolvers.parseOffset({'dx': 1, 'dy': 2}),
          const Offset(1, 2));
      expect(TomStyleResolvers.parseOffset({'x': 3, 'y': 4}),
          const Offset(3, 4));
      expect(TomStyleResolvers.parseOffset([5, 6]), const Offset(5, 6));
    });
  });

  group('TomStyleResolvers.parseTableBorder', () {
    test('all shorthand applies to every side', () {
      final tb = TomStyleResolvers.parseTableBorder({
        'all': {'color': '#FF0000', 'width': 2},
      })!;
      expect(tb.top.color, const Color(0xFFFF0000));
      expect(tb.verticalInside.width, 2.0);
    });
  });

  group('TomStyleResolvers.parseVisualDensity', () {
    test('named and custom', () {
      expect(TomStyleResolvers.parseVisualDensity('compact'),
          VisualDensity.compact);
      expect(TomStyleResolvers.parseVisualDensity({'horizontal': 1, 'vertical': 2}),
          const VisualDensity(horizontal: 1, vertical: 2));
    });
  });

  group('TomStyleResolvers.parseScrollPhysics', () {
    test('recognised names', () {
      expect(TomStyleResolvers.parseScrollPhysics('bouncing'),
          isA<BouncingScrollPhysics>());
      expect(TomStyleResolvers.parseScrollPhysics('never'),
          isA<NeverScrollableScrollPhysics>());
      expect(TomStyleResolvers.parseScrollPhysics('page'),
          isA<PageScrollPhysics>());
    });

    test('null for unknown', () {
      expect(TomStyleResolvers.parseScrollPhysics('warp'), isNull);
    });
  });

  group('TomStyleResolvers.parseIconThemeData / parseStrutStyle', () {
    test('icon theme data', () {
      final it = TomStyleResolvers.parseIconThemeData({
        'color': '#00FF00',
        'size': 24,
        'opacity': 0.5,
      })!;
      expect(it.color, const Color(0xFF00FF00));
      expect(it.size, 24);
      expect(it.opacity, 0.5);
    });

    test('strut style', () {
      final s = TomStyleResolvers.parseStrutStyle({
        'fontSize': 14,
        'height': 1.4,
        'fontWeight': 'w500',
        'forceStrutHeight': true,
      })!;
      expect(s.fontSize, 14);
      expect(s.height, 1.4);
      expect(s.fontWeight, FontWeight.w500);
      expect(s.forceStrutHeight, true);
    });
  });

  group('TomStyleResolvers.parseTextHeightBehavior', () {
    test('defaults and leading distribution', () {
      final b = TomStyleResolvers.parseTextHeightBehavior({
        'applyHeightToFirstAscent': false,
        'leadingDistribution': 'even',
      })!;
      expect(b.applyHeightToFirstAscent, false);
      expect(b.applyHeightToLastDescent, true);
      expect(b.leadingDistribution, TextLeadingDistribution.even);
    });
  });
}
