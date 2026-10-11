import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../example/widgets/widgets_example.dart' as example;
import 'widget_census.dart';

class _PathAuthAdapter extends TomAuthorizationAdapter {
  final Map<String, TomAuthState> rules;
  _PathAuthAdapter(this.rules);

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = TomAllColorsAdapter();
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  group('widgets example', () {
    test('runs end to end with its assertions', () {
      expect(example.run, returnsNormally);
    });
  });

  // The example's dartdoc promises that no family is left out and that a
  // twenty-first one fails this suite until the example demonstrates it too.
  // These three tests are what make that a checked claim: the permitted set is
  // read from `widget_base/` by `familyBases()`, so adding a branch base moves
  // the expectation and the example has to follow.
  group('family coverage', () {
    test('the example names one widget from every declared family', () {
      final declared = familyBases()
          .map((b) => b.substring('Tom'.length, b.length - 'Base'.length))
          .map((n) => n.toLowerCase())
          .toSet();
      final demonstrated = example.oneWidgetPerFamily().keys.toSet();
      expect(demonstrated, declared);
    });

    test('every entry is keyed by the family its widget actually extends', () {
      // The trap this catches is a representative picked by name rather than
      // by base: `TomSliverList` and `TomOpacity` both read like one family
      // and extend the base of another.
      for (final MapEntry(key: family, value: widget)
          in example.oneWidgetPerFamily().entries) {
        final belongsTo = [
          for (final test in example.familyTest.entries)
            if (test.value(widget)) test.key,
        ];
        expect(belongsTo, [family], reason: '${widget.runtimeType}');
      }
    });

    test('each representative is addressed by its family name', () {
      // The example's output reads `settings.button` only because the ids and
      // the family names are the same string; keep them so.
      for (final MapEntry(key: family, value: widget)
          in example.oneWidgetPerFamily().entries) {
        expect(widget.tomId, family);
        expect(widget.basePath, family);
      }
    });

    test('the family test names every family base exactly once', () {
      // `familyTest` is how the example asks about a family; one with a
      // family missing would make the "exactly one family" check vacuous for
      // every widget of it.
      final declared = familyBases()
          .map((b) => b.substring('Tom'.length, b.length - 'Base'.length))
          .map((n) => n.toLowerCase())
          .toSet();
      expect(example.familyTest.keys.toSet(), declared);
    });
  });

  group('basePath resolution', () {
    test('tomId becomes basePath at the top level', () {
      expect(TomText(tomId: 'greeting', text: 'x').basePath, 'greeting');
    });

    test('basePath is scope-prefixed inside a TomScope', () {
      TomScope.withScope('settings', () {
        expect(
          TomText(tomId: 'greeting', text: 'x').basePath,
          'settings.greeting',
        );
      });
    });
  });

  group('effectiveAuthState resolution (no BuildContext)', () {
    test('resolves from resource auth and defaults to full', () {
      TomAuthorization.adapter = _PathAuthAdapter({'save': TomAuthState.read});
      final saveBtn = TomElevatedButton(
        tomId: 'save',
        onPressed: () {},
        child: TomText(text: 'Save'),
      );
      final freeLabel = TomText(tomId: 'greeting', text: 'Hello');
      expect(saveBtn.effectiveAuthState, TomAuthState.read);
      expect(freeLabel.effectiveAuthState, TomAuthState.full);
    });

    test('a group narrows the member to its ceiling', () {
      TomAuthorization.adapter = _PathAuthAdapter({'tools': TomAuthState.read});
      final tools = TomAuthorizationGroup('tools'); // controlsWidest
      final grouped = TomContainer(
        tomId: 'panel',
        tomGroup: tools,
        child: const SizedBox(),
      );
      expect(grouped.effectiveAuthState, TomAuthState.read);
    });
  });
}
