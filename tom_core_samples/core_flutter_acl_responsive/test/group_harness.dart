// Shared scaffolding for the mechanism suites: pump one showcase group at a
// width wide enough that every cell lays out, and read facts back out of a
// single cell. Not a suite itself.

import 'package:core_flutter_acl_responsive/common/showcase_cell.dart';
import 'package:core_flutter_acl_responsive/common/showcase_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overflow_tolerance.dart';

/// Renders [group] alone, tall and wide enough for every cell.
Future<void> pumpGroup(WidgetTester tester, ShowcaseGroup group) async {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // The cells pin previews to fixed widths that can overflow the preview
  // column - a harness artifact, not a property of the mechanism under test.
  tolerateOverflowErrors();
  await tester.pumpWidget(MaterialApp(home: GroupScreen(group: group)));
  await tester.pump();
}

/// The cell whose title starts with [titlePrefix].
Finder cellTitled(String titlePrefix) => find.byWidgetPredicate(
  (w) => w is ShowcaseCell && w.title.startsWith(titlePrefix),
  description: 'the cell titled "$titlePrefix…"',
);

/// The on-screen rect of the one `Text` inside [cell] reading exactly [text].
Rect textRect(WidgetTester tester, Finder cell, String text) =>
    tester.getRect(find.descendant(of: cell, matching: find.text(text)));

/// The rendered width of the `demoBox` inside [cell] labelled [label].
double boxWidth(WidgetTester tester, Finder cell, String label) => tester
    .getSize(
      find
          .ancestor(
            of: find.descendant(of: cell, matching: find.text(label)),
            matching: find.byType(DecoratedBox),
          )
          .first,
    )
    .width;
