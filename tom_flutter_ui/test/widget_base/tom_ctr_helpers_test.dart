import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

void main() {
  setUpAll(() {
    TomUIColors.adapter = TomAllColorsAdapter();
    TomUIIcons.adapter = TomAllIconsAdapter();
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
      _installResources({
        'b': {'width': 2},
      });
      expect(TomCtr.inputBorder('b'), isNull);
    });

    test('kind=none returns InputBorder.none', () {
      _installResources({
        'b': {'kind': 'none'},
      });
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
      _installResources({
        'b': {'kind': 'outline'},
      });
      final border = TomCtr.inputBorder('b');
      expect(border, isA<OutlineInputBorder>());
      final radius = (border as OutlineInputBorder).borderRadius.resolve(
        TextDirection.ltr,
      );
      expect(radius.topLeft.x, 4.0);
    });

    test('kind=outline uses explicit radius', () {
      _installResources({
        'b': {'kind': 'outline', 'radius': 12, 'color': '#0000FF'},
      });
      final border = TomCtr.inputBorder('b');
      expect(border, isA<OutlineInputBorder>());
      final radius = (border as OutlineInputBorder).borderRadius.resolve(
        TextDirection.ltr,
      );
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
      expect(prop.resolve({WidgetState.selected}), const Color(0xFF222222));
      expect(prop.resolve({WidgetState.disabled}), const Color(0xFF333333));
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
      expect(precedence.keys.toSet(), {
        'hovered',
        'focused',
        'pressed',
        'selected',
        'disabled',
        'error',
        'dragged',
        'scrolledUnder',
      }, reason: 'the dartdoc of widgetStateColor lists exactly these names');
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
          reason:
              '$higher outranks $lower, so a control in both states '
              'must paint the $higher colour',
        );
      }
    });

    test(
      'a pointer resting on a disabled control keeps the disabled colour',
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
        expect(
          prop!.resolve({WidgetState.hovered, WidgetState.disabled}),
          const Color(0xFFDDDDDD),
        );
      },
    );

    test('an invalid control that gains focus keeps the error colour', () {
      _installResources({
        'fill': '#111111',
        'fill.states.focused': '#00FF00',
        'fill.states.error': '#FF0000',
      });
      final prop = TomCtr.widgetStateColor('fill');
      expect(
        prop!.resolve({WidgetState.error, WidgetState.focused}),
        const Color(0xFFFF0000),
      );
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
      _installResources({'fill': '#111111', 'fill.states.hovered': '#AAAAAA'});
      final prop = TomCtr.widgetStateColor('fill');
      expect(
        prop!.resolve({WidgetState.hovered, WidgetState.disabled}),
        const Color(0xFFAAAAAA),
      );
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
          [600, 8],
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

  group('TomCtr …OrFail: the two failure conditions', () {
    // The five `…OrFail` helpers can fail for two independent reasons: there
    // is no `tomId`, so there is no key to look up at all; or there is a key
    // and nothing is installed at it. They agree on the first and disagree on
    // the second — `textOrFail` returns the key, the other four throw — and
    // that disagreement is deliberate, not an oversight. A missing label
    // painted as `checkout.submit.label` is how a missing translation makes
    // itself visible during development, and the suite relies on it:
    // `scope_propagation_test.dart` detects a mis-scoped widget by finding
    // exactly that string on screen.
    //
    // These tests exist because that difference is easy to "tidy up" into
    // consistency by someone reading only the family name. Asserting all five
    // against both conditions in one place is what makes the asymmetry a
    // stated contract rather than an accident of five separate methods.

    group('which accessors carry an …OrFail is a stated rule', () {
      // The line between the accessors that have a throwing variant and those
      // that do not is not "used where a value is structurally required" —
      // that is a property of the *call site*, which cannot be applied when
      // deciding what to give a new accessor, and cannot explain why an icon
      // may never be required. The rule is about the
      // accessor:
      //
      //   an accessor gets an `…OrFail` when the resource it reads can be a
      //   widget's *only* source for a required parameter that has no default.
      //
      // `text`, `color`, `icon`, `double` and `int` all reach such a
      // parameter — a label, a `ColoredBox.color`, a `TomIconButton`'s icon,
      // an `Opacity.opacity`, a `RotatedBox.quarterTurns` — so each has one.
      //
      // The rest are excluded for two distinct reasons, and both survive the
      // question "why not this one too?":
      //
      // - `boolVal` and `edgeInsets` read values whose Flutter parameters
      //   always carry a default, so a resource *overrides* rather than
      //   *supplies*. Every `boolVal` call in this package is
      //   `boolVal(…) ?? aDefault`; a throwing variant would have nothing to
      //   be called from, and adding one would only invite a caller to demand
      //   a flag that `false` already answers.
      // - `value`, `list` and `map` are raw escape hatches. `TomCtr` is not
      //   told what the caller means to do with a `List`, so it cannot decide
      //   what "present but unusable" is — only the caller can, which is why
      //   these three hand back what they found and stop.
      //
      // Scanned from the source rather than called, because the claim is
      // about which members *exist*: a sixth variant added without a thought
      // for the rule would pass every behavioural test in this file.
      final source = File(
        'lib/src/widget_base/tom_construction_helpers.dart',
      ).readAsStringSync();
      final declared = RegExp(
        r'^  static\s+[\w<>?,\s]+?\s(\w+)\(',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toSet();

      test('exactly five accessors have a throwing variant', () {
        expect(
          declared.where((n) => n.endsWith('OrFail')).toList()..sort(),
          <String>[
            'colorOrFail',
            'doubleOrFail',
            'iconOrFail',
            'intOrFail',
            'textOrFail',
          ],
          reason:
              'the …OrFail family changed; if that was deliberate, the '
              'rule above and the table in doc/widget_base.md both state which '
              'accessors have one and why, and both need to say so too',
        );
      });

      test('every throwing variant shadows a plain accessor, and the '
          'excluded accessors exist to be excluded', () {
        // Guards both ends of the line. A variant with no plain partner is a
        // required-only value, which no resource key is; and a rule that
        // excludes five accessors is vacuous if the five are not there.
        const partners = <String, String>{
          'textOrFail': 'text',
          'colorOrFail': 'color',
          'iconOrFail': 'icon',
          'doubleOrFail': 'doubleVal',
          'intOrFail': 'intVal',
        };
        partners.forEach((variant, plain) {
          expect(
            declared,
            containsAll(<String>[variant, plain]),
            reason:
                '$variant has no $plain to fall back to, so a caller who '
                'can live without the value has nowhere to go',
          );
        });

        expect(
          declared,
          containsAll(<String>[
            'boolVal',
            'edgeInsets',
            'value',
            'list',
            'map',
          ]),
          reason:
              'the accessors the rule deliberately leaves unpartnered are '
              'no longer all present, so the rule now excludes nothing',
        );
      });
    });

    group('no tomId — every variant throws', () {
      test('textOrFail(null)', () {
        expect(() => TomCtr.textOrFail(null, 'label'), throwsStateError);
      });

      test('colorOrFail(null)', () {
        expect(() => TomCtr.colorOrFail(null, 'color'), throwsStateError);
      });

      test('iconOrFail(null)', () {
        expect(() => TomCtr.iconOrFail(null, 'icon'), throwsStateError);
      });

      test('doubleOrFail(null)', () {
        expect(() => TomCtr.doubleOrFail(null, 'size'), throwsStateError);
      });

      test('intOrFail(null)', () {
        expect(() => TomCtr.intOrFail(null, 'count'), throwsStateError);
      });
    });

    group('key present, resource absent — only textOrFail survives', () {
      setUp(() => _installResources({}));

      test('textOrFail returns the key it looked up', () {
        expect(TomCtr.textOrFail('nope', 'label'), 'nope.label');
      });

      test('colorOrFail throws', () {
        expect(() => TomCtr.colorOrFail('nope', 'color'), throwsStateError);
      });

      test('iconOrFail throws', () {
        expect(() => TomCtr.iconOrFail('nope', 'icon'), throwsStateError);
      });

      test('doubleOrFail throws', () {
        expect(() => TomCtr.doubleOrFail('nope', 'size'), throwsStateError);
      });

      test('intOrFail throws', () {
        expect(() => TomCtr.intOrFail('nope', 'count'), throwsStateError);
      });

      test('the two conditions are distinguishable on textOrFail alone', () {
        // The one method that answers differently to the two reasons. Stated
        // as a single expectation so the asymmetry cannot be read as two
        // unrelated facts about two unrelated calls.
        expect(TomCtr.textOrFail('nope', 'label'), 'nope.label');
        expect(() => TomCtr.textOrFail(null, 'label'), throwsStateError);
      });
    });

    group('resource present — every variant returns it', () {
      // Without these the throwing tests above would still pass against a
      // helper that threw unconditionally.
      setUp(() {
        _installResources({
          'w.label': 'Submit',
          'w.color': '#FF0000',
          'w.icon': 'mSave',
          'w.size': 12,
          'w.count': 3,
        });
      });

      test(
        'textOrFail',
        () => expect(TomCtr.textOrFail('w', 'label'), 'Submit'),
      );

      test('colorOrFail', () {
        expect(TomCtr.colorOrFail('w', 'color'), const Color(0xFFFF0000));
      });

      test('iconOrFail', () {
        expect(TomCtr.iconOrFail('w', 'icon'), Icons.save);
      });

      test(
        'doubleOrFail',
        () => expect(TomCtr.doubleOrFail('w', 'size'), 12.0),
      );

      test('intOrFail', () => expect(TomCtr.intOrFail('w', 'count'), 3));
    });

    group('resource present but unusable — the third throw reason', () {
      // Distinct from absence: the bundle named the key and got the type
      // wrong. `textOrFail` has no such case — every resource is readable as
      // text — which is the other half of why it cannot answer like the rest.
      setUp(() {
        _installResources({
          'w.color': 'not-a-colour',
          'w.icon': 'notAnIcon',
          'w.size': 'not-a-number',
          'w.count': 'not-a-number',
        });
      });

      test('colorOrFail throws on an unresolvable colour name', () {
        expect(() => TomCtr.colorOrFail('w', 'color'), throwsStateError);
      });

      test('iconOrFail throws on an unresolvable icon name', () {
        // The case the plain `icon` accessor cannot distinguish from absence:
        // both answer `null`, so a caller that needs an icon learns only that
        // it has none, never that the bundle named one that does not exist.
        expect(() => TomCtr.iconOrFail('w', 'icon'), throwsStateError);
      });

      test('doubleOrFail throws on a non-numeric value', () {
        expect(() => TomCtr.doubleOrFail('w', 'size'), throwsStateError);
      });

      test('intOrFail throws on a non-numeric value', () {
        expect(() => TomCtr.intOrFail('w', 'count'), throwsStateError);
      });
    });

    test('supersededBy suppresses textOrFail entirely, tomId or not', () {
      // The third exit. A caller offering a widget slot that renders instead
      // of the text has nothing to demand a resource for, so neither failure
      // condition applies — including the null-tomId one that is otherwise
      // unconditional.
      _installResources({});
      const stand = SizedBox.shrink();
      expect(TomCtr.textOrFail('nope', 'label', supersededBy: stand), '');
      expect(TomCtr.textOrFail(null, 'label', supersededBy: stand), '');
    });
  });
}
