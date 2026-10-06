// What "a showcase cell renders" means, as something a test can check.
//
// Nothing throwing is not it. A demo laid out at zero height throws nothing and
// leaves the page chrome untouched, so a suite that asserts only that stays
// green while the thing a cell exists to show is invisible.
//
// So a cell's demo counts as rendered when its live child has area, and so
// does every label inside it. The second half is the one that matters: a
// layout that squashes one box of a row while its neighbour keeps the row's
// height leaves the child as a whole with area, and only the box is gone. The
// demo boxes all carry a label, so a collapsed box is a label with no area.

import 'package:core_flutter_ui_showcase/common/showcase_cell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How many [ShowcaseCell]s are built in the current tree.
int builtCellCount() => find.byType(ShowcaseCell).evaluate().length;

/// The result of measuring every built cell's demo.
typedef DemoAudit = ({
  List<String> faults,
  int demosMeasured,
  int labelsMeasured,
});

/// Measures every built [ShowcaseCell]'s demo and every label inside it.
///
/// [DemoAudit.faults] holds one line per demo or label with no area, and is
/// empty when everything on screen is visible. [DemoAudit.demosMeasured] and
/// [DemoAudit.labelsMeasured] say how much was looked at, so a caller can tell
/// "nothing collapsed" from "nothing was measured". A demo may carry no label
/// at all (a divider, an icon), so it is the demo count a caller holds to the
/// number of cells.
DemoAudit auditDemos() {
  final faults = <String>[];
  var demosMeasured = 0;
  var labelsMeasured = 0;
  for (final cellElement in find.byType(ShowcaseCell).evaluate()) {
    final cell = cellElement.widget as ShowcaseCell;
    final inCell = find.byElementPredicate((e) => identical(e, cellElement));
    final child = find.descendant(
      of: inCell,
      matching: find.byWidget(cell.child),
    );
    final childBox = child.evaluate().single.renderObject! as RenderBox;
    demosMeasured++;
    if (_isEmpty(childBox.size)) {
      faults.add('"${cell.title}": the demo is ${childBox.size}');
      continue;
    }
    final labels = find.descendant(of: child, matching: find.byType(RichText));
    for (final label in labels.evaluate()) {
      final text = (label.widget as RichText).text.toPlainText().trim();
      if (text.isEmpty) continue;
      labelsMeasured++;
      final size = (label.renderObject! as RenderBox).size;
      if (_isEmpty(size)) {
        faults.add('"${cell.title}": label "$text" is $size');
      }
    }
  }
  return (
    faults: faults,
    demosMeasured: demosMeasured,
    labelsMeasured: labelsMeasured,
  );
}

bool _isEmpty(Size size) => size.width <= 0 || size.height <= 0;
