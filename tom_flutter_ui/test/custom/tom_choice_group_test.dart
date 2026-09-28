/// `TomChoiceGroup`'s own parameters, and its data model.
///
/// The four-state contract and the `enabled: false` second mechanism are in
/// `auth_composite_table_test.dart`, where they are driven across all three
/// auth-gated composites at once. What is left is what only this widget has:
/// the group key being optional, the selection callback, the per-item
/// `description`, the `title`, and `disabledOpacity`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class _Rules implements TomAuthorizationAdapter {
  _Rules(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

const _items = <TomChoiceGroupItem<String>>[
  TomChoiceGroupItem(value: 'a', label: 'Alpha', description: 'the first one'),
  TomChoiceGroupItem(value: 'b', label: 'Beta'),
];

double? _fadeOn(WidgetTester tester, Finder child) {
  final faded = tester
      .widgetList<Opacity>(
        find.ancestor(of: child, matching: find.byType(Opacity)),
      )
      .where((o) => o.opacity < 1.0);
  return faded.isEmpty ? null : faded.first.opacity;
}

void main() {
  tearDown(TomAuthorization.reset);

  group('tomId', () {
    testWidgets('a null tomId means no check at all', (tester) async {
      // Documented as "always full". Without a case, an adapter that withheld
      // everything would be indistinguishable from one nobody asked — and the
      // difference matters, because a group with no key is the ordinary way
      // to use this widget outside an authorized screen.
      TomAuthorization.adapter = _Rules({'': TomAuthState.none});
      var chosen = '';

      await tester.pumpWidget(
        _host(
          TomChoiceGroup<String>(
            items: _items,
            selected: 'a',
            onChanged: (value) => chosen = value,
          ),
        ),
      );

      expect(find.text('Alpha'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(chosen, 'b', reason: 'ungated, so the selection goes through');
    });
  });

  group('onChanged', () {
    testWidgets('reports the item that was tapped, not its index', (
      tester,
    ) async {
      final chosen = <String>[];

      await tester.pumpWidget(
        _host(
          TomChoiceGroup<String>(
            items: _items,
            selected: 'a',
            onChanged: chosen.add,
          ),
        ),
      );

      await tester.tap(find.text('Beta'));
      await tester.pump();
      await tester.tap(find.text('Alpha'));
      await tester.pump();

      expect(chosen, ['b', 'a']);
    });

    testWidgets('a null handler leaves the group inert but rendered', (
      tester,
    ) async {
      // The read-only display case: a caller showing a settled choice has no
      // handler to give, and must not have to fake one.
      await tester.pumpWidget(
        _host(const TomChoiceGroup<String>(items: _items, selected: 'a')),
      );

      expect(find.text('Alpha'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pump();
      // Nothing to assert but the absence of a crash — which is the claim.
      expect(tester.takeException(), isNull);
    });
  });

  group('presentation', () {
    testWidgets('an item description is rendered beneath its label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TomChoiceGroup<String>(items: _items, selected: 'a')),
      );

      expect(find.text('the first one'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('the first one')).dy,
        greaterThan(tester.getTopLeft(find.text('Alpha')).dy),
        reason: 'beneath the label it belongs to, not beside it',
      );
    });

    testWidgets('an item without a description renders only its label', (
      tester,
    ) async {
      // The control: `Beta` has none, so a widget that rendered an empty line
      // for it would be caught here rather than looking like whitespace.
      await tester.pumpWidget(
        _host(const TomChoiceGroup<String>(items: _items, selected: 'a')),
      );

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(texts, containsAll(<String>['Alpha', 'Beta', 'the first one']));
      expect(texts, hasLength(3));
    });

    testWidgets('a title is rendered above the options', (tester) async {
      await tester.pumpWidget(
        _host(
          const TomChoiceGroup<String>(
            title: 'Density',
            items: _items,
            selected: 'a',
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Density')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy),
      );
    });
  });

  group('disabledOpacity', () {
    testWidgets('is the fade applied at disabled', (tester) async {
      TomAuthorization.adapter = _Rules({'choice': TomAuthState.disabled});

      await tester.pumpWidget(
        _host(
          const TomChoiceGroup<String>(
            tomId: 'choice',
            disabledOpacity: 0.23,
            items: _items,
            selected: 'a',
          ),
        ),
      );

      expect(_fadeOn(tester, find.text('Alpha')), 0.23);
    });

    testWidgets('read is not faded, whatever it is set to', (tester) async {
      TomAuthorization.adapter = _Rules({'choice': TomAuthState.read});

      await tester.pumpWidget(
        _host(
          const TomChoiceGroup<String>(
            tomId: 'choice',
            disabledOpacity: 0.23,
            items: _items,
            selected: 'a',
          ),
        ),
      );

      expect(_fadeOn(tester, find.text('Alpha')), isNull);
    });
  });

  group('TomChoiceGroupItem', () {
    test('keeps value, label and description', () {
      const item = TomChoiceGroupItem(
        value: 7,
        label: 'Seven',
        description: 'a prime',
      );

      expect(item.value, 7);
      expect(item.label, 'Seven');
      expect(item.description, 'a prime');
    });

    test('a description is optional', () {
      const item = TomChoiceGroupItem(value: 7, label: 'Seven');
      expect(item.description, isNull);
    });
  });
}
