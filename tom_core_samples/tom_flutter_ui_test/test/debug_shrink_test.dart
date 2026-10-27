/// Diagnostic: measure rendered widths in size_constraints panel 4
/// (mixed + expandX) at a range of viewport widths to understand the
/// shrink behaviour the user reported.
///
/// The measurements are printed, and the properties they show are asserted:
/// with room to spare the fixed components sit at their preferred size and
/// the `expandX` one takes the rest; as the viewport narrows every component
/// shrinks and none grows; none ever goes below its minimum size; and below
/// the summed minimum (328 px) every component pins to its minimum and the row
/// overflows by design.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';

void main() {
  const capKey = ValueKey('cap');
  const uncapAKey = ValueKey('uncapA');
  const uncapBKey = ValueKey('uncapB');
  const expandKey = ValueKey('expand');

  Widget buildAcl() {
    return AclBuilder()
        .append(
          const KeyedSubtree(key: capKey, child: DemoBox('Cap', Colors.cyan)),
        )
        .setMSize(80, 40)
        .setPSize(160, 40)
        .setXSize(260, 40)
        .append(
          const KeyedSubtree(
            key: uncapAKey,
            child: DemoBox('A', Colors.indigo),
          ),
          dist: 6,
        )
        .setMSize(60, 40)
        .setPSize(140, 40)
        .append(
          const KeyedSubtree(
            key: uncapBKey,
            child: DemoBox('B', Colors.orange),
          ),
          dist: 6,
        )
        .setMSize(50, 40)
        .setPSize(120, 40)
        .append(
          const KeyedSubtree(
            key: expandKey,
            child: DemoBox('ExpandX', Colors.lightGreen),
          ),
          dist: 6,
        )
        .setMSize(120, 40)
        .setPSize(240, 40)
        .setAttr(AclFlags.expandX)
        .build();
  }

  /// Minimum and preferred widths as the builder declares them.
  const minimum = {'cap': 80.0, 'A': 60.0, 'B': 50.0, 'expand': 120.0};
  const preferred = {'cap': 160.0, 'A': 140.0, 'B': 120.0};
  const gaps = 3 * 6.0;

  Future<Map<String, double>> measure(WidgetTester tester, double w) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: w, child: buildAcl()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final cap = tester.getRect(find.byKey(capKey));
    final a = tester.getRect(find.byKey(uncapAKey));
    final b = tester.getRect(find.byKey(uncapBKey));
    final e = tester.getRect(find.byKey(expandKey));
    // ignore: avoid_print
    print(
      'width=$w  cap=${cap.width.toStringAsFixed(1)}  '
      'A=${a.width.toStringAsFixed(1)}  '
      'B=${b.width.toStringAsFixed(1)}  '
      'expand=${e.width.toStringAsFixed(1)}  '
      'total=${(cap.width + a.width + b.width + e.width + 18).toStringAsFixed(1)}',
    );

    // Why: below the components' summed minimumSize (cap 80 + A 60 + B 50 +
    // expand 120 + 3×dist 18 = 328px) the row cannot shrink any further and
    // overflows by design — that minimumSize floor is exactly the behaviour
    // this diagnostic documents (see the 300px row: every component pins to
    // its minimum, total 328 > 300). The overflow is recorded as a pending
    // FlutterError that would otherwise fail the test at teardown; drain it
    // so the measurement loop still completes, while re-surfacing anything
    // that is not an expected overflow.
    final pending = tester.takeException();
    if (pending != null && !pending.toString().contains('overflowed')) {
      fail('Unexpected exception at width=$w: $pending');
    }
    return {'cap': cap.width, 'A': a.width, 'B': b.width, 'expand': e.width};
  }

  testWidgets('size_constraints panel 4 shrink at multiple widths', (
    tester,
  ) async {
    const widths = [800.0, 600.0, 500.0, 448.0, 400.0, 350.0, 300.0];
    final rows = [for (final w in widths) await measure(tester, w)];
    final floor = minimum.values.reduce((x, y) => x + y) + gaps;

    for (var i = 0; i < widths.length; i++) {
      final row = rows[i];
      for (final entry in minimum.entries) {
        expect(
          row[entry.key],
          greaterThanOrEqualTo(entry.value - 0.5),
          reason: '${entry.key} below its minimum at ${widths[i]} px',
        );
      }
      expect(row['cap'], lessThanOrEqualTo(260.5), reason: 'cap over max');
      if (i > 0) {
        for (final key in row.keys) {
          expect(
            row[key],
            lessThanOrEqualTo(rows[i - 1][key]! + 0.5),
            reason: '$key grew as the viewport narrowed to ${widths[i]} px',
          );
        }
      }
    }

    // Room to spare: the fixed components take their preferred size, and the
    // expandX component takes what is left.
    for (final entry in preferred.entries) {
      expect(rows.first[entry.key], closeTo(entry.value, 0.5));
    }
    expect(rows.first['expand'], greaterThan(240));

    // Between the floor and preferred, the row fills the same share of the
    // viewport at every width - the components shrink together.
    final fill =
        widths.first - (rows.first.values.reduce((x, y) => x + y) + gaps);
    for (var i = 0; i < widths.length; i++) {
      if (widths[i] - fill < floor) continue;
      final total = rows[i].values.reduce((x, y) => x + y) + gaps;
      expect(total, closeTo(widths[i] - fill, 0.5), reason: '${widths[i]} px');
    }

    // Below the floor: every component pins to its minimum.
    expect(widths.last, lessThan(floor));
    for (final entry in minimum.entries) {
      expect(rows.last[entry.key], closeTo(entry.value, 0.5));
    }
  });
}
