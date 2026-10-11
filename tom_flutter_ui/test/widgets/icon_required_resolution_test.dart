import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// An icon is required for some widgets and optional for others. Resolving
// both cases through `TomCtr.icon` cannot tell them apart: it answers `null`
// to absence and to a misspelt name alike.
//
// For `TomIconButton` the icon *is* the widget. When neither the parameter nor
// the resource supplied one it rendered `Icons.error_outline` — a control that
// is present, tappable, and shows a generic warning glyph naming neither the
// widget nor the key it looked for. That is the case `…OrFail` exists for, so
// it now resolves through `TomCtr.iconOrFail` and stops.
//
// `TomFloatingActionButton.extended` is the counter-example that keeps the
// rule from becoming "icons are always required": its icon sits beside a
// label, its absence simply means no icon, and it must keep resolving through
// the nullable accessor. Both directions are asserted here, because a change
// that made one of them wrong would look locally reasonable.
//
// The throw is raised by the *constructor* — `_initResolvedFields` runs in the
// initialiser body — so these use `expect(() => TomX(), throwsStateError)`
// rather than a pump.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void _installResources(Map<String, dynamic> tree) {
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from(tree),
  );
}

void main() {
  setUpAll(() => TomUIIcons.adapter = TomAllIconsAdapter());

  tearDown(() => _installResources(<String, dynamic>{}));

  group('tcinc791: TomIconButton cannot render without an icon', () {
    testWidgets('tcinc791-01: an explicit icon needs no resource', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(TomIconButton(icon: const Icon(Icons.add), onPressed: () {})),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets(
      'tcinc791-02: an icon resource is used when no icon is passed',
      (tester) async {
        _installResources(<String, dynamic>{
          'save': {'icon': 'mSave'},
        });
        await tester.pumpWidget(
          _host(TomIconButton(tomId: 'save', onPressed: () {})),
        );
        expect(find.byIcon(Icons.save), findsOneWidget);
      },
    );

    test('tcinc791-03: no icon and no tomId throws', () {
      expect(() => TomIconButton(onPressed: () {}), throwsStateError);
    });

    test('tcinc791-04: a tomId with no icon resource throws', () {
      _installResources(<String, dynamic>{});
      expect(
        () => TomIconButton(tomId: 'save', onPressed: () {}),
        throwsStateError,
      );
    });

    test('tcinc791-05: an icon name no adapter can resolve throws', () {
      // The failure the previous placeholder hid completely: the bundle did
      // name an icon, and the name is wrong. Absence and a typo used to reach
      // the same silent `Icons.error_outline`.
      _installResources(<String, dynamic>{
        'save': {'icon': 'notAnIcon'},
      });
      expect(
        () => TomIconButton(tomId: 'save', onPressed: () {}),
        throwsStateError,
      );
    });

    test('tcinc791-06: the message names the key that was missing', () {
      // A diagnostic that does not say *which* resource is absent leaves the
      // reader grepping a bundle, which is most of what the placeholder cost.
      _installResources(<String, dynamic>{});
      expect(
        () => TomIconButton(tomId: 'save', onPressed: () {}),
        throwsA(
          isStateError.having(
            (e) => e.message,
            'message',
            contains('save.icon'),
          ),
        ),
      );
    });
  });

  group('tcinc791: an icon beside a label stays optional', () {
    testWidgets('tcinc791-07: an extended FAB builds with no icon resource', (
      tester,
    ) async {
      _installResources(<String, dynamic>{
        'submit': {'label': 'Submit'},
      });
      await tester.pumpWidget(
        _host(
          TomFloatingActionButton.extended(tomId: 'submit', onPressed: () {}),
        ),
      );
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('tcinc791-08: an extended FAB still reads one when present', (
      tester,
    ) async {
      _installResources(<String, dynamic>{
        'submit': {'label': 'Submit', 'icon': 'mSave'},
      });
      await tester.pumpWidget(
        _host(
          TomFloatingActionButton.extended(tomId: 'submit', onPressed: () {}),
        ),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);
    });
  });

  group('tcinc791: TomIcon resolves through the accessor, not by hand', () {
    // `TomIcon` read the same resource through `TomCtr.textOrFail` and then
    // decided whether it had found anything by asking whether the answer
    // ended in `.icon` — because `textOrFail` returns the *key* when the
    // resource is absent. That is a second implementation of what
    // `TomCtr.icon` already does, and it reads the returned value as if it
    // were a key: an icon actually *named* something ending in `.icon` is
    // indistinguishable from a missing one and is silently dropped.
    //
    // `TomIcon` keeps the nullable accessor — an icon whose name a bundle
    // does not supply is a legitimate no-icon `Icon(null)`, which is why this
    // is not a second `…OrFail` site.

    tearDown(TomUIIcons.clearCustomIcons);

    testWidgets('tcinc791-09: a resource icon name is resolved', (
      tester,
    ) async {
      _installResources(<String, dynamic>{
        'logo': {'icon': 'mSave'},
      });
      await tester.pumpWidget(_host(TomIcon(tomId: 'logo')));
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('tcinc791-10: an absent resource leaves no icon', (
      tester,
    ) async {
      _installResources(<String, dynamic>{});
      await tester.pumpWidget(_host(TomIcon(tomId: 'logo')));
      expect(tester.widget<Icon>(find.byType(Icon)).icon, isNull);
    });

    testWidgets(
      'tcinc791-11: an icon named like a key is not mistaken for one',
      (tester) async {
        TomUIIcons.registerIcons(<String, IconData>{
          'brand.icon': Icons.star,
        });
        _installResources(<String, dynamic>{
          'logo': {'icon': 'brand.icon'},
        });
        await tester.pumpWidget(_host(TomIcon(tomId: 'logo')));
        expect(find.byIcon(Icons.star), findsOneWidget);
      },
    );
  });
}
