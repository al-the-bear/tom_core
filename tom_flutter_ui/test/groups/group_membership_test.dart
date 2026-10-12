/// A group's members are the Tom widgets currently in the tree.
///
/// A widget instance is replaced on every parent rebuild and is never told it
/// left the tree, so membership is held by its element
/// ([TomGroupMemberElement]): joined on mount, moved to the new instance on
/// update, given up on deactivate. These tests pin that for each element kind
/// the package creates — stateless (`TomNodeBase`, `TomAuthGate`, `TomSpacer`),
/// stateful (`TomRefreshProgressIndicator`) and parent-data (`TomExpanded`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class _AllowAll implements TomAuthorizationAdapter {
  @override
  TomAuthState resolveAuth(String path) => TomAuthState.full;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => TomAuthorization.adapter = _AllowAll());
  tearDown(TomAuthorization.reset);

  group('a mounted widget is a member exactly once', () {
    testWidgets('GL-1: rebuilding a gate five times leaves one member', (
      tester,
    ) async {
      final group = TomAuthorizationGroup('g');
      late TomAuthGate last;
      for (var i = 0; i < 5; i++) {
        last = TomAuthGate(tomId: 'x', tomGroup: group, child: Text('$i'));
        await tester.pumpWidget(_host(last));
      }
      expect(group.memberCount, 1);
      expect(group.findMember('x'), same(last));
    });

    testWidgets('GL-2: a removed gate is no longer a member', (tester) async {
      final group = TomAuthorizationGroup('g');
      await tester.pumpWidget(
        _host(TomAuthGate(tomId: 'x', tomGroup: group, child: const Text('s'))),
      );
      expect(group.memberCount, 1);
      await tester.pumpWidget(_host(const SizedBox()));
      expect(group.memberCount, 0);
    });

    testWidgets('GL-3: a constructed but unmounted widget is not a member', (
      tester,
    ) async {
      final group = TomAuthorizationGroup('g');
      TomAuthGate(tomId: 'x', tomGroup: group, child: const Text('s'));
      TomText(tomId: 't', tomGroup: group, text: 't');
      expect(group.memberCount, 0);
    });

    testWidgets('GL-4: a rebuild that changes the group moves the membership', (
      tester,
    ) async {
      final a = TomAuthorizationGroup('a');
      final b = TomAuthorizationGroup('b');
      await tester.pumpWidget(
        _host(TomAuthGate(tomId: 'x', tomGroup: a, child: const Text('s'))),
      );
      await tester.pumpWidget(
        _host(TomAuthGate(tomId: 'x', tomGroup: b, child: const Text('s'))),
      );
      expect(a.memberCount, 0);
      expect(b.memberCount, 1);
    });

    testWidgets('GL-5: a gate told not to join stays out while mounted, and '
        'joins once a rebuild says it may', (tester) async {
      final group = TomAuthorizationGroup('g');
      Widget gate(bool joins) => _host(
        TomAuthGate(
          tomId: 'x',
          tomGroup: group,
          joinsGroup: joins,
          child: const Text('s'),
        ),
      );
      await tester.pumpWidget(gate(false));
      expect(group.memberCount, 0);
      await tester.pumpWidget(gate(true));
      expect(group.memberCount, 1);
      await tester.pumpWidget(gate(false));
      expect(group.memberCount, 0);
    });

    testWidgets('GL-6: a widget moved by its GlobalKey stays one member', (
      tester,
    ) async {
      final group = TomAuthorizationGroup('g');
      final key = GlobalKey();
      Widget gate() => TomAuthGate(
        key: key,
        tomId: 'x',
        tomGroup: group,
        child: const Text('s'),
      );
      await tester.pumpWidget(_host(Column(children: [gate()])));
      await tester.pumpWidget(_host(Row(children: [SizedBox(child: gate())])));
      expect(group.memberCount, 1);
    });
  });

  group('every element kind the package creates keeps membership', () {
    final kinds = <String, Widget Function(TomAuthorizationGroup)>{
      'TomText (TomNodeBase, stateless)': (g) =>
          TomText(tomId: 'w', tomGroup: g, text: 'w'),
      'TomSpacer (stateless wrapper)': (g) => Row(
        children: [TomSpacer(tomId: 'w', tomGroup: g)],
      ),
      'TomExpanded (parent data)': (g) => Row(
        children: [
          TomExpanded(tomId: 'w', tomGroup: g, child: const Text('w')),
        ],
      ),
      'TomRefreshProgressIndicator (stateful)': (g) =>
          TomRefreshProgressIndicator(tomId: 'w', tomGroup: g, value: 0.5),
    };

    for (final entry in kinds.entries) {
      testWidgets('GL-7: ${entry.key}', (tester) async {
        final group = TomAuthorizationGroup('g');
        for (var i = 0; i < 3; i++) {
          await tester.pumpWidget(_host(entry.value(group)));
        }
        expect(group.memberCount, 1, reason: 'one member after three builds');
        expect(group.findMember('w'), isNotNull);
        await tester.pumpWidget(_host(const SizedBox()));
        expect(group.memberCount, 0, reason: 'none after removal');
      });
    }
  });
}
