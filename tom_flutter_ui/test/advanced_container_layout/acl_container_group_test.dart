/// `setAclGroup`: the container's group is the outermost default of the group
/// chain.
///
/// A component belongs to its own group, else its row's, else the container's.
/// The container's group was stored, forwarded and read by nothing, so an
/// application that grouped a container got no error and no effect; these
/// tests are what it would have needed to fail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

/// Shows the group [AclScope] reports for the widget it sits in.
Widget _reportsGroup(String label) => Builder(
  builder: (context) =>
      Text('$label:${AclScope.of(context)?.groupName ?? '-'}'),
);

Future<void> _pump(WidgetTester tester, Widget layout) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SizedBox(width: 800, child: layout)),
  ),
);

AclGroupVisibilityController _hidden() =>
    AclBinaryVisibilityController(initialMode: AclGroupVisibilityMode.hidden);

void main() {
  group('ACG-1: a container group [2026-09-30]', () {
    testWidgets('ACG-1: hides every component that names no group of its own', (
      tester,
    ) async {
      await _pump(
        tester,
        AclBuilder()
            .setAclGroup('g')
            .setGroupVisibilityController('g', _hidden())
            .append(const Text('ungrouped'))
            .append(const Text('own'))
            .group('other')
            .build(),
      );
      expect(find.text('ungrouped'), findsNothing);
      expect(find.text('own'), findsOneWidget);
    });

    testWidgets('ACG-2: a row group keeps its row out of the container group', (
      tester,
    ) async {
      await _pump(
        tester,
        AclBuilder()
            .setAclGroup('g')
            .setGroupVisibilityController('g', _hidden())
            .append(const Text('first row'))
            .newRow()
            .setRowGroup('r')
            .append(const Text('second row'))
            .build(),
      );
      expect(find.text('first row'), findsNothing);
      expect(find.text('second row'), findsOneWidget);
    });

    testWidgets(
      'ACG-3: AclScope reports the group each component resolved to',
      (tester) async {
        await _pump(
          tester,
          AclBuilder()
              .setAclGroup('g')
              .append(_reportsGroup('plain'))
              .append(_reportsGroup('own'))
              .group('c')
              .newRow()
              .setRowGroup('r')
              .append(_reportsGroup('row'))
              .build(),
        );
        expect(find.text('plain:g'), findsOneWidget);
        expect(find.text('own:c'), findsOneWidget);
        expect(find.text('row:r'), findsOneWidget);
      },
    );

    testWidgets('ACG-4: without a container group, an ungrouped component is '
        'no group\'s', (tester) async {
      await _pump(
        tester,
        AclBuilder()
            .setGroupVisibilityController('g', _hidden())
            .append(const Text('ungrouped'))
            .append(_reportsGroup('plain'))
            .build(),
      );
      expect(find.text('ungrouped'), findsOneWidget);
      expect(find.text('plain:-'), findsOneWidget);
    });
  });
}
