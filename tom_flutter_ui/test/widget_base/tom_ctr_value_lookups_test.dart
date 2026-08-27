import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_colors.dart';
import 'package:tom_flutter_ui/src/resource_auth/tom_icons.dart';
import 'package:tom_flutter_ui/src/widget_base/tom_construction_helpers.dart';
import 'package:tom_flutter_ui/src/widgets/labels/tom_labels.dart';

// `tom_ctr_helpers_test.dart` covers the four compound helpers (`textStyle`,
// `inputBorder`, `widgetStateColor`, `breakpointed`) and the four `…OrFail`
// variants. This file covers the other half of `TomCtr`: the plain lookups
// that read one resource and coerce it to one type.
//
// They look interchangeable — thirteen one-liners over the same provider — and
// that is the hazard. They disagree in four ways that no reader would predict
// from the signatures, and each disagreement is a real call site's behaviour:
//
//   * on a null basePath they return four different things (`''`, `null`,
//     `false`, and a `SizedBox`);
//   * on an absent resource `text` returns the key while `value` returns null;
//   * `color` accepts an int, `icon` does not;
//   * `textOrNull` reports a non-String resource as absent while `value`
//     returns it and `exists` says it is there.
//
// The tests are grouped by those seams rather than one group per method, so a
// change that makes two of them agree fails next to the reason they differ.

void install(Map<String, dynamic> tree) =>
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(tree),
    );

void main() {
  setUpAll(() {
    TomUIColors.adapter = AllColorsAdapter();
    TomUIIcons.adapter = AllIconsAdapter();
  });

  tearDown(() => install(<String, dynamic>{}));

  group('TomCtr: the key is basePath plus an optional dotted suffix', () {
    // Every lookup composes its key the same way through one private helper.
    // Asserting it once on a representative method beats repeating it
    // thirteen times, but it has to be asserted somewhere: the empty-suffix
    // case is what lets a caller pass a fully pre-resolved path, which is the
    // documented first of the two usage patterns.
    test('an empty suffix uses basePath verbatim', () {
      install({'a.b': 'flat', 'a': {'b': 'tree'}});
      expect(TomCtr.value('a.b'), isNotNull);
    });

    test('a non-empty suffix is joined with a dot', () {
      install({'w': {'label': 'Save'}});
      expect(TomCtr.textOrNull('w', 'label'), 'Save');
      expect(TomCtr.textOrNull('w.label'), 'Save');
    });

    test('the suffix defaults to empty', () {
      install({'w': 'Save'});
      expect(TomCtr.textOrNull('w'), 'Save');
    });
  });

  group('TomCtr: a null basePath is an exit, and they disagree on it', () {
    // Nothing here reads a resource — the point is what each method answers
    // when there is no key to look one up with. A widget built without a
    // tomId takes this path for every one of its lookups, so "returns null"
    // is not a safe blanket assumption to code against.
    setUp(() => install(<String, dynamic>{}));

    test('text yields the empty string, not null', () {
      // It returns a String, so it has no null to give; the empty string is
      // what a caller renders when there is nothing to render.
      expect(TomCtr.text(null), '');
      expect(TomCtr.text(null, 'label'), '');
    });

    test('exists yields false, not null', () {
      expect(TomCtr.exists(null), isFalse);
      expect(TomCtr.exists(null, 'label'), isFalse);
    });

    test('defaultTextOrEmpty yields a shrunken box, not null', () {
      expect(TomCtr.defaultTextOrEmpty(null), isA<SizedBox>());
    });

    test('every other lookup yields null', () {
      final lookups = <String, Object? Function()>{
        'textOrNull': () => TomCtr.textOrNull(null, 'label'),
        'color': () => TomCtr.color(null, 'color'),
        'icon': () => TomCtr.icon(null, 'icon'),
        'doubleVal': () => TomCtr.doubleVal(null, 'size'),
        'intVal': () => TomCtr.intVal(null, 'count'),
        'boolVal': () => TomCtr.boolVal(null, 'flag'),
        'edgeInsets': () => TomCtr.edgeInsets(null, 'pad'),
        'value': () => TomCtr.value(null, 'raw'),
        'list': () => TomCtr.list(null, 'items'),
        'map': () => TomCtr.map(null, 'style'),
        'textStyle': () => TomCtr.textStyle(null, 'style'),
        'defaultText': () => TomCtr.defaultText(null),
        'childTomId': () => TomCtr.childTomId(null, 'child'),
        'resolvePath': () => TomCtr.resolvePath(null),
      };
      for (final entry in lookups.entries) {
        expect(entry.value(), isNull, reason: '${entry.key}(null) must be null');
      }
    });
  });

  group('TomCtr: an absent resource is not the same exit as a null path', () {
    // The key exists, nothing is installed at it. `text` deliberately paints
    // the key so a missing translation is visible on screen during
    // development; `value` and the coercing lookups return null so a caller
    // can fall back. Confusing the two is how a literal "w.label" ends up in
    // a shipped build, so both halves are stated here.
    setUp(() => install(<String, dynamic>{}));

    test('text returns the key it looked up', () {
      expect(TomCtr.text('w', 'label'), 'w.label');
    });

    test('textOrNull returns null for the same lookup', () {
      expect(TomCtr.textOrNull('w', 'label'), isNull);
    });

    test('value returns null rather than the key', () {
      // `value` reaches for `getObjectOrNull`, not `getObject` — the latter
      // has the same key-as-fallback behaviour as `getText` and would hand
      // every coercing lookup a String to misread.
      expect(TomCtr.value('w', 'raw'), isNull);
    });

    test('exists says false', () {
      expect(TomCtr.exists('w', 'label'), isFalse);
    });
  });

  group('TomCtr: the String family reports a non-String as absent', () {
    // The subtlest seam in the class. One resource, three lookups, three
    // different answers — and all three are correct. `textOrNull` speaks for
    // the provider's String family, which filters by type; `value` speaks for
    // the object family, which does not; `exists` deliberately asks both, so
    // it answers for the union.
    setUp(() => install({'w': {'n': 5}}));

    test('textOrNull reads nothing from a numeric resource', () {
      expect(TomCtr.textOrNull('w', 'n'), isNull);
    });

    test('text falls back to the key for a numeric resource', () {
      expect(TomCtr.text('w', 'n'), 'w.n');
    });

    test('value returns the number', () {
      expect(TomCtr.value('w', 'n'), 5);
    });

    test('exists is true — it asks the object family as well', () {
      // Broader than the provider's own `exists`, on purpose: a widget asking
      // "did the bundle say anything about this?" wants yes for a Color or a
      // size, not only for text.
      expect(TomCtr.exists('w', 'n'), isTrue);
    });
  });

  group('TomCtr.color: names, hex, and packed ints', () {
    test('resolves a hex string', () {
      install({'w': {'c': '#FF0000'}});
      expect(TomCtr.color('w', 'c'), const Color(0xFFFF0000));
    });

    test('resolves an adapter colour name', () {
      install({'w': {'c': 'mRed'}});
      expect(TomCtr.color('w', 'c'), TomUIColors.resolveColor('mRed'));
      expect(TomCtr.color('w', 'c'), isNotNull);
    });

    test('accepts a packed int', () {
      install({'w': {'c': 0xFF00FF00}});
      expect(TomCtr.color('w', 'c'), const Color(0xFF00FF00));
    });

    test('returns null for an unresolvable name', () {
      install({'w': {'c': 'notAColour'}});
      expect(TomCtr.color('w', 'c'), isNull);
    });

    test('returns null for a type it cannot read', () {
      install({'w': {'c': 12.5}, 'x': {'c': <String>[]}});
      expect(TomCtr.color('w', 'c'), isNull);
      expect(TomCtr.color('x', 'c'), isNull);
    });

    test('returns null when absent', () {
      install(<String, dynamic>{});
      expect(TomCtr.color('w', 'c'), isNull);
    });
  });

  group('TomCtr.icon: names only', () {
    test('resolves an adapter icon name', () {
      install({'w': {'i': 'mSave'}});
      expect(TomCtr.icon('w', 'i'), Icons.save);
    });

    test('returns null for an unresolvable name', () {
      install({'w': {'i': 'notAnIcon'}});
      expect(TomCtr.icon('w', 'i'), isNull);
    });

    test('rejects an int, unlike color', () {
      // Deliberate asymmetry with `color`, which reads an int as packed ARGB.
      // An icon has no such self-describing integer form — a bare code point
      // is meaningless without the font family it belongs to — so a number
      // here is a bundle mistake rather than a second spelling.
      install({'w': {'i': Icons.save.codePoint}});
      expect(TomCtr.icon('w', 'i'), isNull);
    });

    test('returns null when absent', () {
      install(<String, dynamic>{});
      expect(TomCtr.icon('w', 'i'), isNull);
    });
  });

  group('TomCtr.doubleVal / intVal: the same number written four ways', () {
    // Both accept a number or a numeric string, and both truncate rather than
    // reject when asked for an int. The table drives the two together because
    // the property that matters is that they agree: a bundle that quotes its
    // numbers (YAML and env-derived bundles routinely do) must not read
    // differently from one that does not.
    const numbers = <String, Object>{
      'int': 3,
      'double': 3.0,
      'intString': '3',
      'doubleString': '3.0',
    };

    for (final entry in numbers.entries) {
      test('doubleVal reads a ${entry.key}', () {
        install({'w': {'n': entry.value}});
        expect(TomCtr.doubleVal('w', 'n'), 3.0);
      });

      test('intVal reads a ${entry.key}', () {
        install({'w': {'n': entry.value}});
        expect(TomCtr.intVal('w', 'n'), 3);
      });
    }

    test('intVal truncates a fractional value, however it is written', () {
      // The numeric route has always truncated. The string route must reach
      // the same answer or the two spellings of one resource disagree.
      install({'w': {'a': 3.7, 'b': '3.7'}});
      expect(TomCtr.intVal('w', 'a'), 3);
      expect(TomCtr.intVal('w', 'b'), 3);
    });

    test('both return null for a non-numeric string', () {
      install({'w': {'n': 'not-a-number'}});
      expect(TomCtr.doubleVal('w', 'n'), isNull);
      expect(TomCtr.intVal('w', 'n'), isNull);
    });

    test('both return null for a non-numeric type', () {
      install({'w': {'n': true}});
      expect(TomCtr.doubleVal('w', 'n'), isNull);
      expect(TomCtr.intVal('w', 'n'), isNull);
    });

    test('both return null when absent', () {
      install(<String, dynamic>{});
      expect(TomCtr.doubleVal('w', 'n'), isNull);
      expect(TomCtr.intVal('w', 'n'), isNull);
    });
  });

  group('TomCtr.boolVal: bools and their two spellings', () {
    test('reads a real bool', () {
      install({'w': {'t': true, 'f': false}});
      expect(TomCtr.boolVal('w', 't'), isTrue);
      expect(TomCtr.boolVal('w', 'f'), isFalse);
    });

    test('reads true/false in any case', () {
      install({
        'w': {'a': 'true', 'b': 'TRUE', 'c': 'False', 'd': 'fAlSe'},
      });
      expect(TomCtr.boolVal('w', 'a'), isTrue);
      expect(TomCtr.boolVal('w', 'b'), isTrue);
      expect(TomCtr.boolVal('w', 'c'), isFalse);
      expect(TomCtr.boolVal('w', 'd'), isFalse);
    });

    test('rejects the numeric spellings', () {
      // Unlike the numeric lookups, this one does not widen to 1/0. A bundle
      // is authored, not scraped, and every format it is authored in has a
      // real boolean — so a number here is a mistake worth surfacing as null
      // rather than guessing which way it points.
      install({'w': {'a': 1, 'b': 0}});
      expect(TomCtr.boolVal('w', 'a'), isNull);
      expect(TomCtr.boolVal('w', 'b'), isNull);
    });

    test('rejects other words for yes and no', () {
      install({'w': {'a': 'yes', 'b': 'off', 'c': ''}});
      expect(TomCtr.boolVal('w', 'a'), isNull);
      expect(TomCtr.boolVal('w', 'b'), isNull);
      expect(TomCtr.boolVal('w', 'c'), isNull);
    });

    test('returns null when absent', () {
      install(<String, dynamic>{});
      expect(TomCtr.boolVal('w', 'f'), isNull);
    });

    test('false is distinguishable from absent only by nullability', () {
      // The reason this method returns `bool?` and not `bool`. A caller that
      // applies `?? false` collapses the two, which is usually right and
      // occasionally the bug.
      install({'w': {'f': false}});
      expect(TomCtr.boolVal('w', 'f'), isFalse);
      expect(TomCtr.boolVal('w', 'missing'), isNull);
    });
  });

  group('TomCtr.value / list / map: raw access and its two filters', () {
    test('value returns whatever is there, uncoerced', () {
      install({
        'w': {
          'a': 'text',
          'b': 7,
          'c': true,
          'd': [1, 2],
        },
      });
      expect(TomCtr.value('w', 'a'), 'text');
      expect(TomCtr.value('w', 'b'), 7);
      expect(TomCtr.value('w', 'c'), true);
      expect(TomCtr.value('w', 'd'), [1, 2]);
    });

    test('list returns a list and filters everything else', () {
      install({
        'w': {
          'items': [1, 'two', null],
          'scalar': 5,
          'map': {'a': 1},
        },
      });
      expect(TomCtr.list('w', 'items'), [1, 'two', null]);
      expect(TomCtr.list('w', 'scalar'), isNull);
      expect(TomCtr.list('w', 'map'), isNull);
      expect(TomCtr.list('w', 'missing'), isNull);
    });

    test('map returns a sub-tree and filters everything else', () {
      install({
        'w': {
          'style': {'fontSize': 12, 'color': '#FF0000'},
          'scalar': 5,
          'list': [1],
        },
      });
      expect(TomCtr.map('w', 'style'), {'fontSize': 12, 'color': '#FF0000'});
      expect(TomCtr.map('w', 'scalar'), isNull);
      expect(TomCtr.map('w', 'list'), isNull);
      expect(TomCtr.map('w', 'missing'), isNull);
    });

    test('map requires string keys', () {
      // The filter is `Map<String, dynamic>`, not `Map`. A bundle decoded
      // from JSON always satisfies it; one built by hand with a non-String
      // key does not, and reads as absent rather than throwing at the cast.
      install({
        'w': <String, dynamic>{
          'ok': <String, int>{'a': 1},
          'bad': <int, String>{1: 'a'},
        },
      });
      expect(TomCtr.map('w', 'ok'), {'a': 1});
      expect(TomCtr.map('w', 'bad'), isNull);
    });
  });

  group('TomCtr: the child-widget helpers', () {
    test('childTomId joins parent and suffix', () {
      expect(TomCtr.childTomId('card', 'title'), 'card.title');
      expect(TomCtr.childTomId('a.b', 'c'), 'a.b.c');
    });

    test('childTomId propagates the absent parent', () {
      // The reason it exists rather than being inlined as string
      // interpolation: `'$tomId.$suffix'` on a null parent yields the string
      // "null.title", which then resolves as a resource key and paints it.
      expect(TomCtr.childTomId(null, 'title'), isNull);
    });

    test('defaultText builds a TomText carrying id, scope and group', () {
      install({'card': {'title': 'Hello'}});
      final scope = TomScopeBase(scopeId: 'admin');
      final group = TomAuthorizationGroup('editors');
      final widget = TomCtr.defaultText('card.title', scope, group);
      expect(widget, isNotNull);
      expect(widget!.tomId, 'card.title');
      expect(widget.scope, same(scope));
      expect(widget.tomGroup, same(group));
    });

    test('defaultText returns null without an id', () {
      expect(TomCtr.defaultText(null), isNull);
    });

    test('defaultTextOrEmpty builds the same widget when given an id', () {
      install({'card': {'title': 'Hello'}});
      final widget = TomCtr.defaultTextOrEmpty('card.title');
      expect(widget, isA<TomText>());
      expect((widget as TomText).tomId, 'card.title');
    });

    test('defaultTextOrEmpty substitutes an empty box without an id', () {
      // The whole difference between the two: one is for an optional slot a
      // caller may leave null, the other for a required slot that must always
      // produce a widget. Neither throws.
      final widget = TomCtr.defaultTextOrEmpty(null);
      expect(widget, isA<SizedBox>());
      expect((widget as SizedBox).width, 0.0);
      expect(widget.height, 0.0);
    });
  });
}
