import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// What a Tom wrapper does when the text resource it asks for is not there.
//
// `TomCtr.textOrFail` is the module's text resolver — roughly seventy call
// sites across twelve files use it — and its name is misleading in a specific
// way: it throws when there is *nothing to look up* (a null `basePath`), but
// when a `tomId` is present and the resource is absent it returns the dotted
// key as a `String`, deliberately, so a missing translation is visible on
// screen instead of crashing the app. `test/widget_base/tom_ctr_helpers_test`
// pins that at the resolver.
//
// This file pins it one layer up, at the widgets, because the resolver's
// answer is not the widget's behaviour: each call site composes it, and there
// are three distinct compositions in `lib/src/widgets/`, giving three
// different answers to the same missing resource. That is what a caller
// actually meets, and it is not derivable from the resolver's contract alone.
//
//   (a) required     `x ?? TomCtr.textOrFail(basePath, k)`
//                    tomId + no resource -> renders the key
//                    no tomId            -> throws
//   (b) optional     `x ?? (tomId != null ? TomCtr.textOrFail(basePath, k)
//                                         : null)`
//                    tomId + no resource -> renders the key
//                    no tomId            -> null, and the widget is fine
//   (c) superseded   `x ?? TomCtr.textOrFail(basePath, k, supersededBy: w)`
//                    a widget in the slot -> '' without any lookup
//                    otherwise as (a)
//   (d) if present   `x ?? TomCtr.textOrNull(basePath, k)`
//                    tomId + no resource -> null, and no such text is shown
//                    tomId + resource    -> the resource's text
//
// (d) is the composition of a text a widget can do without and that most
// screens leave out: a text field's helper, prefix and suffix, a tile's
// subtitle, a dropdown menu form field's helper. Under (b) every field with a
// tomId would show `name.helper` until a resource was written for it.
//
// The tests run against the ambient resource provider with no resources
// registered, which is the state a developer hits on the first run of a new
// screen.
//
// Note that the throwing cases are raised by the *constructor*, not by build,
// so they are `expect(() => TomX(), throwsStateError)` rather than pump
// assertions.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The placeholder the [CupertinoTextField] under [finder] was handed.
String? _placeholderOf(WidgetTester tester, Finder finder) =>
    tester.widget<CupertinoTextField>(finder).placeholder;

void main() {
  group('tccd1: (a) a required text renders its own key', () {
    testWidgets(
      'tccd1-01: TomText with a tomId and no resource shows the key',
      (tester) async {
        // The case both `doc/widgets.md` and the completion document once said
        // throws. It does not, and the string it paints looks enough like a
        // label to ship: it is the right size, in the right place, and reads as
        // words.
        await tester.pumpWidget(_host(TomText(tomId: 'nope')));
        expect(find.text('nope.label'), findsOneWidget);
      },
    );

    testWidgets('tccd1-02: an explicit text needs no resource', (tester) async {
      await tester.pumpWidget(_host(TomText(text: 'Hello')));
      expect(find.text('Hello'), findsOneWidget);
    });

    test('tccd1-03: TomText with neither text nor tomId throws', () {
      // The only failure `textOrFail` raises: nothing to look up. Note this is
      // a different mistake from the one above, and the one that is easy to
      // mistake the guarantee for.
      expect(() => TomText(), throwsStateError);
    });

    testWidgets('tccd1-04: TomTooltip with a tomId and no resource shows '
        'the key', (tester) async {
      await tester.pumpWidget(
        _host(TomTooltip(tomId: 'help', child: const SizedBox.shrink())),
      );
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'help.tooltip',
      );
    });

    test('tccd1-05: TomTooltip with neither message nor tomId throws', () {
      expect(
        () => TomTooltip(child: const SizedBox.shrink()),
        throwsStateError,
      );
    });

    testWidgets('tccd1-06: TomTextField labels and hints with its own keys', (
      tester,
    ) async {
      // The label reaches `textOrFail` through the decoration chain rather
      // than directly, and comes out the same way.
      await tester.pumpWidget(_host(TomTextField(tomId: 'name')));
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.labelText, 'name.label');
      expect(decoration.hintText, 'name.hint');
    });
  });

  group('tccd1: (b) an optional text is skipped without a tomId', () {
    testWidgets(
      'tccd1-07: TomCupertinoTextField with a tomId and no resource shows '
      'the key',
      (tester) async {
        await tester.pumpWidget(_host(TomCupertinoTextField(tomId: 'search')));
        expect(
          _placeholderOf(tester, find.byType(CupertinoTextField)),
          'search.hint',
        );
      },
    );

    testWidgets('tccd1-08: TomCupertinoTextField without a tomId has no '
        'placeholder', (tester) async {
      // The guard is what makes the difference: a hint is optional in Flutter,
      // so no tomId means no lookup rather than a throw.
      await tester.pumpWidget(_host(TomCupertinoTextField()));
      expect(_placeholderOf(tester, find.byType(CupertinoTextField)), isNull);
    });

    testWidgets(
      'tccd1-09: TomCupertinoSearchTextField with a tomId and no resource '
      'shows the key',
      (tester) async {
        await tester.pumpWidget(_host(TomCupertinoSearchTextField(tomId: 'q')));
        expect(
          _placeholderOf(tester, find.byType(CupertinoTextField)),
          'q.hint',
        );
      },
    );

    testWidgets('tccd1-10: TomCupertinoSearchTextField without a tomId keeps '
        "Flutter's localized placeholder", (tester) async {
      // `CupertinoSearchTextField` falls back to the localized "Search" when
      // handed a null placeholder. This widget used to resolve the hint
      // unguarded, so it both demanded a tomId to construct at all and, given
      // one, replaced that default with 'q.hint'. Only the first half was
      // wrong; the guard restores the default for the tomId-less case.
      await tester.pumpWidget(_host(TomCupertinoSearchTextField()));
      expect(_placeholderOf(tester, find.byType(CupertinoTextField)), 'Search');
    });

    testWidgets('tccd1-11: TomCupertinoTextFormFieldRow without a tomId has no '
        'placeholder', (tester) async {
      await tester.pumpWidget(
        _host(Form(child: TomCupertinoTextFormFieldRow())),
      );
      expect(_placeholderOf(tester, find.byType(CupertinoTextField)), isNull);
    });
  });

  group('tccd1: (c) a widget in the slot supersedes the lookup', () {
    testWidgets('tccd1-12: TomElevatedButton with a tomId and no resource '
        'shows the key', (tester) async {
      await tester.pumpWidget(
        _host(TomElevatedButton(tomId: 'save', onPressed: () {})),
      );
      expect(find.text('save.label'), findsOneWidget);
    });

    testWidgets('tccd1-13: a child supersedes the label without any lookup', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(TomElevatedButton(onPressed: () {}, child: const Text('Save'))),
      );
      expect(find.text('Save'), findsOneWidget);
    });

    test(
      'tccd1-14: TomElevatedButton with no child, label or tomId throws',
      () {
        expect(() => TomElevatedButton(onPressed: () {}), throwsStateError);
      },
    );

    testWidgets('tccd1-15: TomFilterChip with a tomId and no resource shows '
        'the key', (tester) async {
      await tester.pumpWidget(
        _host(
          TomFilterChip(tomId: 'unread', selected: false, onSelected: (_) {}),
        ),
      );
      expect(find.text('unread.label'), findsOneWidget);
    });
  });

  group('tccd1: (d) an optional text is shown only when its resource '
      'exists', () {
    void install(Map<String, dynamic> resources) {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(resources),
      );
      addTearDown(
        () => TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider.from(const {}),
        ),
      );
    }

    InputDecoration decorationOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).decoration!;

    testWidgets('tccd1-17: TomTextField without helper, prefix or suffix '
        'resources shows none of them', (tester) async {
      install({
        'name': {'label': 'Name', 'hint': 'Your name'},
      });
      await tester.pumpWidget(_host(TomTextField(tomId: 'name')));
      final d = decorationOf(tester);
      expect(d.helperText, isNull);
      expect(d.prefixText, isNull);
      expect(d.suffixText, isNull);
      expect(find.text('name.helper'), findsNothing);
    });

    testWidgets('tccd1-18: TomTextField reads helper, prefix and suffix from '
        'its resources', (tester) async {
      install({
        'price': {
          'label': 'Price',
          'hint': '0.00',
          'helper': 'Including VAT',
          'prefix': 'EUR',
          'suffix': 'per month',
        },
      });
      await tester.pumpWidget(_host(TomTextField(tomId: 'price')));
      final d = decorationOf(tester);
      expect(d.helperText, 'Including VAT');
      expect(d.prefixText, 'EUR');
      expect(d.suffixText, 'per month');
    });

    testWidgets('tccd1-19: TomTextFormField reads the helper from its '
        'resources, and an explicit decoration wins', (tester) async {
      install({
        'mail': {'label': 'Mail', 'hint': 'you@example.com', 'helper': 'Work'},
      });
      await tester.pumpWidget(
        _host(Form(child: TomTextFormField(tomId: 'mail'))),
      );
      expect(decorationOf(tester).helperText, 'Work');
      await tester.pumpWidget(
        _host(
          Form(
            child: TomTextFormField(
              tomId: 'mail',
              decoration: const InputDecoration(helperText: 'Private'),
            ),
          ),
        ),
      );
      expect(decorationOf(tester).helperText, 'Private');
    });

    testWidgets('tccd1-20: a list tile shows a subtitle resource, and none '
        'without one', (tester) async {
      install({
        'wifi': {'label': 'Wi-Fi', 'subtitle': 'Connected'},
        'bt': {'label': 'Bluetooth'},
      });
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              TomListTile(tomId: 'wifi'),
              TomSwitchListTile(tomId: 'bt', value: true, onChanged: (_) {}),
            ],
          ),
        ),
      );
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('bt.subtitle'), findsNothing);
    });

    testWidgets('tccd1-21: a subtitle widget supersedes the resource', (
      tester,
    ) async {
      install({
        'wifi': {'label': 'Wi-Fi', 'subtitle': 'Connected'},
      });
      await tester.pumpWidget(
        _host(TomListTile(tomId: 'wifi', subtitle: const Text('Off'))),
      );
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('tccd1-22: TomDropdownMenuFormField without a helper resource '
        'shows no helper', (tester) async {
      install({
        'size': {'label': 'Size', 'hint': 'Pick one'},
      });
      await tester.pumpWidget(
        _host(
          TomDropdownMenuFormField<int>(
            tomId: 'size',
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 1, label: 'One'),
            ],
          ),
        ),
      );
      expect(find.text('size.helper'), findsNothing);
    });
  });

  group('tccd1: one text, one key', () {
    void install(Map<String, dynamic> resources) {
      TomTextResourceProvider.setAppResourceProvider(
        TomTextResourceProvider.from(resources),
      );
      addTearDown(
        () => TomTextResourceProvider.setAppResourceProvider(
          TomTextResourceProvider.from(const {}),
        ),
      );
    }

    testWidgets('tccd1-23: a tile and an app bar take their title from '
        'label; a titleText resource is not read', (tester) async {
      install({
        'tile': {'label': 'Row', 'titleText': 'Old'},
        'bar': {'label': 'Settings', 'titleText': 'Old title'},
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: TomAppBar(tomId: 'bar'),
            body: TomCupertinoListTile(tomId: 'tile'),
          ),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Row'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      expect(find.text('Old title'), findsNothing);
    });

    testWidgets('tccd1-24: the dropdown menu reads hint, helper and error; '
        'hintText, helperText and errorText resources are not read', (
      tester,
    ) async {
      install({
        'size': {
          'label': 'Size',
          'hint': 'Pick one',
          'helper': 'Shoe size',
          'error': 'Required',
          'hintText': 'Old hint',
          'helperText': 'Old helper',
          'errorText': 'Old error',
        },
      });
      await tester.pumpWidget(
        _host(
          TomDropdownMenu<int>(
            tomId: 'size',
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 1, label: 'One'),
            ],
          ),
        ),
      );
      final menu = tester.widget<DropdownMenu<int>>(
        find.byType(DropdownMenu<int>),
      );
      expect(menu.hintText, 'Pick one');
      expect(menu.helperText, 'Shoe size');
      expect(menu.errorText, 'Required');
    });
  });

  group('tccd1: the key is what reaches the screen, not a blank', () {
    testWidgets(
      'tccd1-16: every missing-resource widget paints a non-empty string',
      (tester) async {
        // The documents used to contrast this behaviour with "rendering blank",
        // which had it backwards: blank is the visibly-wrong outcome that gets
        // caught, and none of these produce it. Asserted together because the
        // shared property is the point — the failure mode is uniform across the
        // shapes even though the compositions differ.
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                TomText(tomId: 'a'),
                TomElevatedButton(tomId: 'b', onPressed: () {}),
                TomFilterChip(tomId: 'c', selected: false, onSelected: (_) {}),
              ],
            ),
          ),
        );
        for (final key in ['a.label', 'b.label', 'c.label']) {
          expect(find.text(key), findsOneWidget);
          expect(key, isNotEmpty);
        }
      },
    );
  });
}
