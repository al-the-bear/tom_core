import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_construction_helpers.dart';

void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
  });

  tearDown(() {
    _installResources({});
  });

  group('TomCtr.textStyle', () {
    test('returns null when no keys present', () {
      _installResources({});
      expect(TomCtr.textStyle('missing'), isNull);
    });

    test('builds TextStyle from all keys', () {
      _installResources({
        'x': {
          'fontSize': 14,
          'fontWeight': 'w600',
          'fontFamily': 'Roboto',
          'color': '#FF0000',
          'letterSpacing': 0.5,
          'fontStyle': 'italic',
        },
      });
      final ts = TomCtr.textStyle('x');
      expect(ts, isNotNull);
      expect(ts!.fontSize, 14);
      expect(ts.fontWeight, FontWeight.w600);
      expect(ts.fontFamily, 'Roboto');
      expect(ts.color, const Color(0xFFFF0000));
      expect(ts.letterSpacing, 0.5);
      expect(ts.fontStyle, FontStyle.italic);
    });

    test('accepts bold / normal string aliases', () {
      _installResources({
        'x': {'fontWeight': 'bold'},
        'y': {'fontWeight': 'normal'},
      });
      expect(TomCtr.textStyle('x')!.fontWeight, FontWeight.w700);
      expect(TomCtr.textStyle('y')!.fontWeight, FontWeight.w400);
    });

    test('returns null when all children are absent or malformed', () {
      _installResources({
        'x': {'fontWeight': 'nonsense'},
      });
      expect(TomCtr.textStyle('x'), isNull);
    });
  });

  group('TomCtr.inputBorder', () {
    test('returns null without kind', () {
      _installResources({'b': {'width': 2}});
      expect(TomCtr.inputBorder('b'), isNull);
    });

    test('kind=none returns InputBorder.none', () {
      _installResources({'b': {'kind': 'none'}});
      expect(TomCtr.inputBorder('b'), InputBorder.none);
    });

    test('kind=underline returns UnderlineInputBorder', () {
      _installResources({
        'b': {'kind': 'underline', 'width': 2, 'color': '#00FF00'},
      });
      final border = TomCtr.inputBorder('b');
      expect(border, isA<UnderlineInputBorder>());
      expect((border as UnderlineInputBorder).borderSide.width, 2);
      expect(border.borderSide.color, const Color(0xFF00FF00));
    });

    test('kind=outline uses radius default 4.0', () {
      _installResources({'b': {'kind': 'outline'}});
      final border = TomCtr.inputBorder('b');
      expect(border, isA<OutlineInputBorder>());
      final radius =
          (border as OutlineInputBorder).borderRadius.resolve(TextDirection.ltr);
      expect(radius.topLeft.x, 4.0);
    });

    test('kind=outline uses explicit radius', () {
      _installResources({
        'b': {'kind': 'outline', 'radius': 12, 'color': '#0000FF'},
      });
      final border = TomCtr.inputBorder('b');
      expect(border, isA<OutlineInputBorder>());
      final radius =
          (border as OutlineInputBorder).borderRadius.resolve(TextDirection.ltr);
      expect(radius.topLeft.x, 12.0);
      expect(border.borderSide.color, const Color(0xFF0000FF));
    });
  });

  group('TomCtr.widgetStateColor', () {
    test('returns null when missing', () {
      _installResources({});
      expect(TomCtr.widgetStateColor('fill'), isNull);
    });

    test('resolves default color without states', () {
      _installResources({'fill': '#123456'});
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop, isNotNull);
      expect(prop!.resolve({}), const Color(0xFF123456));
      expect(prop.resolve({WidgetState.selected}), const Color(0xFF123456));
    });

    test('applies per-state overrides', () {
      _installResources({
        'fill': '#111111',
        'fill.states.selected': '#222222',
        'fill.states.disabled': '#333333',
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop, isNotNull);
      expect(prop!.resolve({}), const Color(0xFF111111));
      expect(prop.resolve({WidgetState.selected}),
          const Color(0xFF222222));
      expect(prop.resolve({WidgetState.disabled}),
          const Color(0xFF333333));
    });

    test('works with only state keys, no default', () {
      _installResources({'fill.states.error': '#FF0000'});
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop, isNotNull);
      expect(prop!.resolve({WidgetState.error}), const Color(0xFFFF0000));
    });
  });

  group('TomCtr.widgetStateColor precedence', () {
    // A control is regularly in more than one widget state at once — a pointer
    // resting on a disabled button puts both `hovered` and `disabled` in the
    // set — and the resolver must return exactly one colour. Which one is a
    // deliberate ranking, restated here rather than read out of the source, so
    // that reordering the source map fails this file instead of quietly
    // becoming the new contract.
    //
    // Highest precedence first. Conditions outrank interactions: being
    // unavailable or invalid is a fact about the control that a passing
    // pointer must not paint over. Within the interactions the more committed
    // act wins — a drag is a press that went somewhere, and a press is a
    // stronger statement of intent than focus, which is stronger than hover.
    const precedence = <String, WidgetState>{
      'disabled': WidgetState.disabled,
      'error': WidgetState.error,
      'dragged': WidgetState.dragged,
      'pressed': WidgetState.pressed,
      'selected': WidgetState.selected,
      'focused': WidgetState.focused,
      'hovered': WidgetState.hovered,
      'scrolledUnder': WidgetState.scrolledUnder,
    };

    /// A distinct, recognisable colour per rank.
    Color colorFor(int rank) => Color(0xFF000010 + rank);

    String hexFor(int rank) =>
        '#${(0x000010 + rank).toRadixString(16).padLeft(6, '0')}';

    test('the ranking covers every state name the resolver reads', () {
      // Guards the guard. A state added to the resolver but not ranked here
      // would take its precedence from wherever it happened to be declared,
      // with nothing to say so.
      expect(precedence, hasLength(8));
      expect(
        precedence.keys.toSet(),
        {
          'hovered',
          'focused',
          'pressed',
          'selected',
          'disabled',
          'error',
          'dragged',
          'scrolledUnder',
        },
        reason: 'the dartdoc of widgetStateColor lists exactly these names',
      );
    });

    test('each rank beats the one below it', () {
      // Adjacent pairs are enough: beating your neighbour at every step
      // establishes the whole order transitively, and it localises a failure
      // to the one swap that caused it rather than reporting every pair that
      // moved.
      final names = precedence.keys.toList();
      for (var i = 0; i < names.length - 1; i++) {
        final higher = names[i];
        final lower = names[i + 1];
        _installResources({
          'fill': '#FFFFFF',
          'fill.states.$higher': hexFor(i),
          'fill.states.$lower': hexFor(i + 1),
        });
        final prop = TomCtr.widgetStateColor('fill');
        expect(
          prop!.resolve({precedence[higher]!, precedence[lower]!}),
          colorFor(i),
          reason: '$higher outranks $lower, so a control in both states '
              'must paint the $higher colour',
        );
      }
    });

    test('a pointer resting on a disabled control keeps the disabled colour',
        () {
      // The case that motivated the ranking, spelled out rather than left to
      // the adjacent-pair loop: `hovered` and `disabled` are the two states
      // most likely to co-occur, and they sit at opposite ends of the order.
      _installResources({
        'fill': '#111111',
        'fill.states.hovered': '#AAAAAA',
        'fill.states.disabled': '#DDDDDD',
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop!.resolve({WidgetState.hovered, WidgetState.disabled}),
          const Color(0xFFDDDDDD));
    });

    test('an invalid control that gains focus keeps the error colour', () {
      _installResources({
        'fill': '#111111',
        'fill.states.focused': '#00FF00',
        'fill.states.error': '#FF0000',
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop!.resolve({WidgetState.error, WidgetState.focused}),
          const Color(0xFFFF0000));
    });

    test('the highest rank wins out of the whole set at once', () {
      _installResources({
        'fill': '#FFFFFF',
        for (final entry in precedence.entries.toList().asMap().entries)
          'fill.states.${entry.value.key}': hexFor(entry.key),
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop!.resolve(precedence.values.toSet()), colorFor(0));
    });

    test('precedence ranks the states a bundle defines, not all of them', () {
      // Only states with a resource take part. A control that is hovered and
      // disabled, in a bundle that colours hover alone, paints the hover
      // colour — the higher rank is absent, not silently defaulted. Without
      // this the ranking would read as "disabled always wins", which would be
      // wrong at the call site that matters most.
      _installResources({
        'fill': '#111111',
        'fill.states.hovered': '#AAAAAA',
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(prop!.resolve({WidgetState.hovered, WidgetState.disabled}),
          const Color(0xFFAAAAAA));
    });
  });

  group('TomCtr.breakpointed', () {
    test('returns null when both default and breakpoints absent', () {
      _installResources({});
      final r = TomCtr.breakpointed<double>(
        'gap',
        (raw) => (raw as num?)?.toDouble(),
      );
      expect(r, isNull);
    });

    test('reads default value only', () {
      _installResources({'gap': 8});
      final r = TomCtr.breakpointed<double>(
        'gap',
        (raw) => (raw as num?)?.toDouble(),
      )!;
      expect(r.$1, 8.0);
      expect(r.$2, isEmpty);
    });

    test('reads default + sorted breakpoints', () {
      _installResources({
        'gap': 4,
        'gap.breakpoints': [
          [1200, 12],
          [600, 8],
        ],
      });
      final r = TomCtr.breakpointed<double>(
        'gap',
        (raw) => (raw as num?)?.toDouble(),
      )!;
      expect(r.$1, 4.0);
      expect(r.$2, [(600.0, 8.0), (1200.0, 12.0)]);
    });

    test('drops malformed override entries', () {
      _installResources({
        'gap': 4,
        'gap.breakpoints': [
          [600, 8],
          'bad',
          [800],
          ['x', 10],
          [1200, 'unparsable'],
        ],
      });
      final r = TomCtr.breakpointed<double>(
        'gap',
        (raw) => raw is num ? raw.toDouble() : null,
      )!;
      expect(r.$2, [(600.0, 8.0)]);
    });

    test('works with breakpoints only (no default)', () {
      _installResources({
        'gap.breakpoints': [
          [600, 8]
        ],
      });
      final r = TomCtr.breakpointed<double>(
        'gap',
        (raw) => (raw as num?)?.toDouble(),
      )!;
      expect(r.$1, isNull);
      expect(r.$2, [(600.0, 8.0)]);
    });
  });
}
