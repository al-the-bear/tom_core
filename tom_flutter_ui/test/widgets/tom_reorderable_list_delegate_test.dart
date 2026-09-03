import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// bug §34 + tests §25: TomReorderableList.buildContent force-cast its
// `childrenDelegate` to SliverChildBuilderDelegate, so a caller passing the
// equally-valid SliverChildListDelegate (the common `SliverChildListDelegate([...])`
// form) hit a runtime CastError. These pin that BOTH stock delegate shapes
// render through a real pump.

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 400, width: 300, child: child)),
);

void main() {
  testWidgets('renders from a SliverChildListDelegate (bug §34)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TomReorderableList(
          childrenDelegate: SliverChildListDelegate([
            const ListTile(key: ValueKey('a'), title: Text('item-a')),
            const ListTile(key: ValueKey('b'), title: Text('item-b')),
          ]),
          onReorderItem: (_, _) {},
        ),
      ),
    );

    expect(find.text('item-a'), findsOneWidget);
    expect(find.text('item-b'), findsOneWidget);
  });

  testWidgets('still renders from a SliverChildBuilderDelegate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TomReorderableList(
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) =>
                ListTile(key: ValueKey(index), title: Text('row-$index')),
            childCount: 3,
          ),
          onReorderItem: (_, _) {},
        ),
      ),
    );

    expect(find.text('row-0'), findsOneWidget);
    expect(find.text('row-1'), findsOneWidget);
    expect(find.text('row-2'), findsOneWidget);
  });

  // RCK21: Flutter 3.44 replaced onReorder with onReorderItem, whose newIndex
  // is ALREADY adjusted for the removed item — so the standard
  // `removeAt(old)`/`insert(new)` body is correct WITHOUT the classic
  // `if (newIndex > oldIndex) newIndex -= 1` fixup. This pins that the
  // TomReorderableListView wrapper forwards onReorderItem with those adjusted
  // semantics: dragging the first row down one slot yields [b, a, c].
  testWidgets('onReorderItem delivers adjusted index (move down one slot)', (
    tester,
  ) async {
    // On desktop platforms ReorderableListView reorders via explicit drag
    // handles; force a mobile platform so a long-press on the row body picks
    // it up, keeping the drag simple. (Reset before the test body returns so
    // the foundation-debug-var invariant check passes.)
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final items = <String>['a', 'b', 'c'];
    int? reportedOld;
    int? reportedNew;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          TomReorderableListView(
            onReorderItem: (oldIndex, newIndex) {
              reportedOld = oldIndex;
              reportedNew = newIndex;
              setState(() {
                final moved = items.removeAt(oldIndex);
                items.insert(newIndex, moved);
              });
            },
            children: [
              for (final label in items)
                ListTile(key: ValueKey(label), title: Text(label)),
            ],
          ),
        ),
      ),
    );

    // Long-press the first row to pick it up, drag down past the second row,
    // then drop.
    final dropTarget = tester.getCenter(find.text('c'));
    final drag = await tester.startGesture(tester.getCenter(find.text('a')));
    // Hold past the long-press threshold (500ms) so the row is picked up.
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(dropTarget);
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await tester.pumpAndSettle();

    expect(items, <String>['b', 'a', 'c']);
    // newIndex must be the post-removal destination (1), not the pre-removal
    // index (2) — proving the manual `newIndex -= 1` fixup is gone.
    expect(reportedOld, 0);
    expect(reportedNew, 1);

    debugDefaultTargetPlatformOverride = null;
  });
}
