import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// tccb2: many Tom wrappers offer a widget slot (`title` / `label`) *and* a
// string slot (`titleText` / `labelText`) that resolves from resources. The
// resolution used to run unconditionally in the constructor, so supplying only
// the widget form still demanded a resource that `buildContent` would never
// read — `TomListTile(title: someWidget)` threw at construction time.
//
// Each widget gets two tests, and both directions matter:
//   * "widget form alone" pins that the widget slot supersedes the string;
//   * "neither form" pins that a genuinely missing resource still fails loudly,
//     so the fix cannot degrade into a silent blank label.
//
// Note the throw is raised by the *constructor*, not by build — hence
// `expect(() => TomX(), throwsStateError)` rather than a pump assertion.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _sliverHost(Widget sliver) =>
    MaterialApp(home: Scaffold(body: CustomScrollView(slivers: [sliver])));

const Widget _marker = Text('widget-form-title');

final Finder _markerFinder = find.text('widget-form-title');

void main() {
  group('tccb2: widget form alone suffices', () {
    testWidgets('tccb2-01: TomListTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(TomListTile(title: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-02: TomCupertinoListTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(TomCupertinoListTile(title: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-03: TomSwitchListTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(
        TomSwitchListTile(value: false, onChanged: (_) {}, title: _marker),
      ));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-04: TomCheckboxListTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(
        TomCheckboxListTile(value: false, onChanged: (_) {}, title: _marker),
      ));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-05: TomRadioListTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(
        TomRadioListTile<String>(value: 'a', title: _marker),
      ));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-06: TomExpansionTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(TomExpansionTile(title: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-07: TomSliverAppBar renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_sliverHost(TomSliverAppBar(title: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-08: TomCupertinoExpansionTile renders a widget title without titleText',
        (tester) async {
      await tester.pumpWidget(_host(
        CupertinoApp(
          home: TomCupertinoExpansionTile(
            title: _marker,
            child: const Text('body'),
          ),
        ),
      ));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets('tccb2-09: TomBadge renders a widget label without labelText',
        (tester) async {
      await tester.pumpWidget(_host(
        TomBadge(label: _marker, child: const Icon(Icons.inbox)),
      ));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets('tccb2-10: TomChip renders a widget label without labelText',
        (tester) async {
      await tester.pumpWidget(_host(TomChip(label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-11: TomFilterChip renders a widget label without labelText',
        (tester) async {
      await tester
          .pumpWidget(_host(TomFilterChip(selected: false, label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-12: TomChoiceChip renders a widget label without labelText',
        (tester) async {
      await tester
          .pumpWidget(_host(TomChoiceChip(selected: false, label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-13: TomActionChip renders a widget label without labelText',
        (tester) async {
      await tester.pumpWidget(_host(TomActionChip(label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets('tccb2-14: TomInputChip renders a widget label without labelText',
        (tester) async {
      await tester.pumpWidget(_host(TomInputChip(label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets('tccb2-15: TomRawChip renders a widget label without labelText',
        (tester) async {
      await tester.pumpWidget(_host(TomRawChip(label: _marker)));
      expect(_markerFinder, findsOneWidget);
    });

    testWidgets(
        'tccb2-16: TomDropdownButtonFormField uses an explicit decoration without a label resource',
        (tester) async {
      await tester.pumpWidget(_host(
        TomDropdownButtonFormField<String>(
          items: const [DropdownMenuItem(value: 'a', child: Text('a'))],
          decoration: const InputDecoration(labelText: 'widget-form-title'),
        ),
      ));
      expect(_markerFinder, findsOneWidget);
    });
  });

  // The chips could not satisfy the tests above while they also demanded a
  // `tooltip` resource, because Flutter treats that parameter as optional and
  // a chip with a widget label has nothing else missing. These pin the same
  // rule for the two wrappers outside the chip family that had it wrong.
  group('tccb2: an optional Flutter slot needs no resource', () {
    testWidgets('tccb2-33: TomIconButton needs no tooltip resource',
        (tester) async {
      await tester.pumpWidget(_host(
        TomIconButton(icon: const Icon(Icons.add), onPressed: () {}),
      ));
      expect(tester.widget<IconButton>(find.byType(IconButton)).tooltip, isNull);
    });

    testWidgets('tccb2-34: TomPopupMenuButton needs no tooltip resource',
        (tester) async {
      await tester.pumpWidget(_host(
        TomPopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'a', child: Text('a')),
          ],
        ),
      ));
      expect(
        tester.widget<PopupMenuButton<String>>(
          find.byType(PopupMenuButton<String>),
        ).tooltip,
        isNull,
      );
    });
  });

  group('tccb2: neither form still fails loudly', () {
    test('tccb2-17: TomListTile without title or titleText throws', () {
      expect(() => TomListTile(), throwsStateError);
    });

    test('tccb2-18: TomCupertinoListTile without title or titleText throws', () {
      expect(() => TomCupertinoListTile(), throwsStateError);
    });

    test('tccb2-19: TomSwitchListTile without title or titleText throws', () {
      expect(() => TomSwitchListTile(value: false), throwsStateError);
    });

    test('tccb2-20: TomCheckboxListTile without title or titleText throws', () {
      expect(() => TomCheckboxListTile(value: false), throwsStateError);
    });

    test('tccb2-21: TomRadioListTile without title or titleText throws', () {
      expect(() => TomRadioListTile<String>(value: 'a'), throwsStateError);
    });

    test('tccb2-22: TomExpansionTile without title or titleText throws', () {
      expect(() => TomExpansionTile(), throwsStateError);
    });

    test('tccb2-23: TomSliverAppBar without title or titleText throws', () {
      expect(() => TomSliverAppBar(), throwsStateError);
    });

    test('tccb2-24: TomCupertinoExpansionTile without title or titleText throws',
        () {
      expect(
        () => TomCupertinoExpansionTile(child: const Text('body')),
        throwsStateError,
      );
    });

    test('tccb2-25: TomBadge without label or labelText throws', () {
      expect(() => TomBadge(), throwsStateError);
    });

    test('tccb2-26: TomChip without label or labelText throws', () {
      expect(() => TomChip(), throwsStateError);
    });

    test('tccb2-27: TomFilterChip without label or labelText throws', () {
      expect(() => TomFilterChip(selected: false), throwsStateError);
    });

    test('tccb2-28: TomChoiceChip without label or labelText throws', () {
      expect(() => TomChoiceChip(selected: false), throwsStateError);
    });

    test('tccb2-29: TomActionChip without label or labelText throws', () {
      expect(() => TomActionChip(), throwsStateError);
    });

    test('tccb2-30: TomInputChip without label or labelText throws', () {
      expect(() => TomInputChip(), throwsStateError);
    });

    test('tccb2-31: TomRawChip without label or labelText throws', () {
      expect(() => TomRawChip(), throwsStateError);
    });

    test('tccb2-32: TomDropdownButtonFormField without decoration throws', () {
      expect(
        () => TomDropdownButtonFormField<String>(items: const []),
        throwsStateError,
      );
    });
  });
}
