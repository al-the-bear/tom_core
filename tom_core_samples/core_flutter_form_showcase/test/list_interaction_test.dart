// The two list-bearing groups are the showcase's interactive cells, and
// `list_form_host_test.dart` only proves they are bound. This suite drives them
// the way a reader would: select a row, then act on it through the toolbar.
//
// Row order in the inline list is read from the product fields' vertical
// positions - the names live inside editable fields (with a price suffix from
// the display transform), so there is no plain `Text` to read in order.

import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/common/showcase_section.dart';
import 'package:core_flutter_form_showcase/groups/lists_group.dart';
import 'package:core_flutter_form_showcase/groups/master_detail_group.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

const _pinion = 'Difference Engine pinion';
const _cards = 'Punched-card deck (1000 pk)';
const _oil = 'Lubricating oil (1L)';

void main() {
  setUpAll(initializeReflection);
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  Future<void> pumpGroup(WidgetTester tester, ShowcaseGroup group) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: GroupScreen(group: group)));
    await tester.pump();
  }

  /// The toolbar button carrying [tooltip].
  IconButton toolbar(WidgetTester tester, String tooltip) => tester.widget(
    find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip),
  );

  group('inline list + toolbar', () {
    /// The products currently in the list, top to bottom.
    List<String> order(WidgetTester tester) {
      final present = [
        for (final p in const [_pinion, _cards, _oil])
          if (find.textContaining(p).evaluate().isNotEmpty) p,
      ];
      present.sort(
        (a, b) => tester
            .getTopLeft(find.textContaining(a).first)
            .dy
            .compareTo(tester.getTopLeft(find.textContaining(b).first).dy),
      );
      return present;
    }

    /// Selects the row showing [product] by tapping the row's own padding, clear
    /// of the fields (a tap on a field would focus it instead).
    Future<void> selectRow(WidgetTester tester, String product) async {
      final card = find
          .ancestor(
            of: find.textContaining(product).first,
            matching: find.byType(Card),
          )
          .first;
      // The card's own InkWell is the outermost one inside it; its 8px padding
      // is clear of the handle and the fields.
      final rowInk = find
          .descendant(of: card, matching: find.byType(InkWell))
          .first;
      await tester.tapAt(tester.getTopLeft(rowInk) + const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    testWidgets('moving a row needs a selection, then reorders the list', (
      tester,
    ) async {
      await pumpGroup(tester, listsGroup);
      expect(order(tester), [_pinion, _cards, _oil]);
      expect(toolbar(tester, 'Move up').onPressed, isNull, reason: 'no row');

      await selectRow(tester, _oil);
      expect(toolbar(tester, 'Move up').onPressed, isNotNull);
      await tester.tap(find.byTooltip('Move up'));
      await tester.pumpAndSettle();

      expect(order(tester), [_pinion, _oil, _cards]);
    });

    testWidgets('Remove deletes the selected row and only it', (tester) async {
      await pumpGroup(tester, listsGroup);
      await selectRow(tester, _cards);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(order(tester), [_pinion, _oil]);
    });
  });

  group('master-detail', () {
    testWidgets(
      'choosing an item in the master pane loads it into the detail',
      (tester) async {
        await pumpGroup(tester, masterDetailGroup);
        // The first item starts selected: it cannot move up, only down.
        expect(toolbar(tester, 'Move up').onPressed, isNull);
        expect(toolbar(tester, 'Move down').onPressed, isNotNull);

        await tester.tap(find.text(_oil));
        await tester.pumpAndSettle();

        // Now the last item: the toolbar's moves flip, and the detail form's
        // product field shows it.
        expect(toolbar(tester, 'Move up').onPressed, isNotNull);
        expect(toolbar(tester, 'Move down').onPressed, isNull);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is EditableText &&
                w.controller.text.startsWith('Lubricating oil'),
          ),
          findsOneWidget,
          reason: 'the detail pane edits the chosen item',
        );
      },
    );
  });
}
