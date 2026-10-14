/// `TomPrincipalPicker`: when it asks the search, which answers it shows,
/// what a pick and a removal report, its authorization states, and what a
/// screen reader hears.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

class _Rules implements TomAuthorizationAdapter {
  _Rules(this.rules);
  final Map<String, TomAuthState> rules;

  @override
  TomAuthState resolveAuth(String path) => rules[path] ?? TomAuthState.full;
}

const _alice = TomPrincipalCandidate(id: 'u1', displayName: 'Alice Archer');
const _albert = TomPrincipalCandidate(id: 'u2', displayName: 'Albert Ames');
const _sales = TomPrincipalCandidate(
  id: 'g1',
  displayName: 'Alpine Sales',
  kind: TomPrincipalKind.group,
);

/// A directory that records every query and answers by prefix.
class _Directory {
  final List<String> queries = [];
  final List<TomPrincipalCandidate> everyone = [_alice, _albert, _sales];
  Completer<void>? gate;
  bool fail = false;

  Future<List<TomPrincipalCandidate>> search(String query) async {
    queries.add(query);
    await gate?.future;
    if (fail) throw StateError('directory unreachable');
    final q = query.toLowerCase();
    return [
      for (final c in everyone)
        if (c.displayName.toLowerCase().startsWith(q)) c,
    ];
  }
}

/// Hosts the picker with its selection in a stateful parent, as a dialog does.
class _Host extends StatefulWidget {
  const _Host({required this.directory, this.multiple = true, this.tomId});
  final _Directory directory;
  final bool multiple;
  final String? tomId;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  List<TomPrincipalCandidate> selected = const [];
  int changes = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: TomPrincipalPicker(
        tomId: widget.tomId,
        search: widget.directory.search,
        selected: selected,
        multiple: widget.multiple,
        onChanged: (next) => setState(() {
          selected = next;
          changes++;
        }),
      ),
    ),
  );
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(TomPrincipalPicker.defaultDebounce);
  await tester.pump();
}

void main() {
  tearDown(TomAuthorization.reset);

  testWidgets('asks only from the third character, after the query rests', (
    tester,
  ) async {
    final directory = _Directory();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'al');
    expect(directory.queries, isEmpty);
    expect(find.text('Type at least 3 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'alpi');
    await tester.pump(TomPrincipalPicker.defaultDebounce);
    await tester.pump();
    expect(directory.queries, ['alpi'], reason: 'one question per pause');
    expect(find.text('Alpine Sales'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('1 found'), findsOneWidget);
  });

  testWidgets('a pick reports the selection, shows a chip, clears the query', (
    tester,
  ) async {
    final directory = _Directory();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'ali');
    await tester.tap(find.text('Alice Archer'));
    await tester.pump();

    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.selected, [_alice]);
    expect(find.widgetWithText(InputChip, 'Alice Archer'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await _type(tester, 'al');
    await _type(tester, 'alb');
    await _type(tester, 'ali');
    expect(
      find.widgetWithText(ListTile, 'Alice Archer'),
      findsNothing,
      reason: 'what is picked is not offered again',
    );
  });

  testWidgets('picks several, or replaces with multiple off', (tester) async {
    final directory = _Directory();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'ali');
    await tester.tap(find.text('Alice Archer'));
    await tester.pump();
    await _type(tester, 'alp');
    await tester.tap(find.text('Alpine Sales'));
    await tester.pump();
    expect(tester.state<_HostState>(find.byType(_Host)).selected, [
      _alice,
      _sales,
    ]);

    await tester.pumpWidget(_Host(directory: directory, multiple: false));
    await _type(tester, 'ali');
    await tester.tap(find.text('Alice Archer'));
    await tester.pump();
    await _type(tester, 'alb');
    await tester.tap(find.text('Albert Ames'));
    await tester.pump();
    expect(tester.state<_HostState>(find.byType(_Host)).selected, [_albert]);
  });

  testWidgets('a chip removes its candidate', (tester) async {
    final directory = _Directory();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'ali');
    await tester.tap(find.text('Alice Archer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove Alice Archer'));
    await tester.pump();
    expect(tester.state<_HostState>(find.byType(_Host)).selected, isEmpty);
  });

  testWidgets('an answer overtaken by a newer query is dropped', (
    tester,
  ) async {
    final directory = _Directory()..gate = Completer<void>();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'ali');
    expect(find.text('Searching'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'alb');
    final slow = directory.gate!;
    directory.gate = null;
    await tester.pump(TomPrincipalPicker.defaultDebounce);
    await tester.pump();
    slow.complete();
    await tester.pump();
    expect(find.text('Albert Ames'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Alice Archer'), findsNothing);
  });

  testWidgets('says when nobody matched, and offers a retry on failure', (
    tester,
  ) async {
    final directory = _Directory();
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'zzz');
    expect(find.text('Nobody found'), findsOneWidget);

    directory.fail = true;
    await _type(tester, 'alb');
    expect(find.text('The search failed'), findsOneWidget);
    directory.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Albert Ames'), findsOneWidget);
  });

  testWidgets('shows at most maximumResults', (tester) async {
    final directory = _Directory()
      ..everyone.addAll([
        for (var i = 0; i < 30; i++)
          TomPrincipalCandidate(id: 'x$i', displayName: 'Alex $i'),
      ]);
    await tester.pumpWidget(_Host(directory: directory));
    await _type(tester, 'ale');
    expect(find.text('20 found'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget, reason: 'the list scrolls');
  });

  group('authorization', () {
    testWidgets('none hides it', (tester) async {
      TomAuthorization.adapter = _Rules({'picker': TomAuthState.none});
      await tester.pumpWidget(_Host(directory: _Directory(), tomId: 'picker'));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('read shows the chips without the field or delete', (
      tester,
    ) async {
      TomAuthorization.adapter = _Rules({'picker': TomAuthState.read});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TomPrincipalPicker(
              tomId: 'picker',
              search: _Directory().search,
              selected: const [_alice],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(InputChip, 'Alice Archer'), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byType(InputChip)).onDeleted,
        isNull,
      );
    });

    testWidgets('disabled dims it as read', (tester) async {
      TomAuthorization.adapter = _Rules({'picker': TomAuthState.disabled});
      await tester.pumpWidget(_Host(directory: _Directory(), tomId: 'picker'));
      expect(find.byType(TextField), findsNothing);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
    });
  });

  testWidgets('a screen reader hears the field, each result and the status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_Host(directory: _Directory()));
    expect(
      find.bySemanticsLabel(RegExp('Find users and groups')),
      findsOneWidget,
    );
    await _type(tester, 'alp');
    final status = tester.getSemantics(find.text('1 found'));
    expect(status, matchesSemantics(label: '1 found', isLiveRegion: true));
    expect(find.bySemanticsLabel(RegExp('Alpine Sales')), findsWidgets);
    handle.dispose();
  });

  test('a candidate is the same by id and kind, not by name', () {
    expect(
      const TomPrincipalCandidate(id: 'u1', displayName: 'Renamed'),
      _alice,
    );
    expect(
      const TomPrincipalCandidate(
        id: 'u1',
        displayName: 'Alice Archer',
        kind: TomPrincipalKind.group,
      ),
      isNot(_alice),
    );
  });
}
