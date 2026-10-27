// ignore_for_file: avoid_print
/// Regression test: TomFormStyleScope with tomId picks up cs.* colour
/// tokens from resources and those colours reach the actual TextField
/// (typed-text colour and floating-label colour) when the ambient Flutter
/// Theme changes.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/forms/company_forms.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _purple = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
  useMaterial3: true,
);
final _teal = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
  useMaterial3: true,
);

/// Wraps [child] in a full app with a given [theme].
Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true), // outer app stays default blue
  home: Scaffold(
    body: SingleChildScrollView(
      child: Theme(
        data: theme,
        child: SizedBox(
          width: 300, // below TomBreakpoint.mobile — no bp override fires
          child: child,
        ),
      ),
    ),
  ),
);

/// Returns the first [TextField] widget found in [tester].
TextField _textField(WidgetTester tester, {int index = 0}) =>
    tester.widget<TextField>(find.byType(TextField).at(index));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    TomUIColors.adapter = TomAllColorsAdapter();
    TomFormStyleScope.invalidateResourceCache();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // ── Setup: the resource overlay (demo10Form) uses cs.primary for
  // inputStyle.color and labelStyle.color. We need the scope to be at
  // < mobile width (300 px) so no @bp.mobile overlay fires.

  group('Demo10 — cs.primary tokens reach the TextField', () {
    late CompanyBasicInfoForm form;

    setUp(() {
      TomFormStyleScope.invalidateResourceCache();
      form = TomScope.withScope(
        'companyBasicInfo',
        () => CompanyBasicInfoForm(),
      );
      // Pre-populate so the floating label is in its floating state.
      form.name.setValue('Acme Corporation');
    });

    tearDown(() => form.dispose());

    Future<void> pumpField(WidgetTester tester, ThemeData theme) =>
        tester.pumpWidget(
          _app(
            theme,
            TomFormStyleScope(
              tomId: 'demo10Form',
              style: const TomFormStyle(),
              child: Builder(builder: (ctx) => form.name.widget),
            ),
          ),
        );

    testWidgets('typed-text colour (TextField.style) follows cs.primary', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpField(tester, _purple);
      await tester.pump();
      final purpleStyle = _textField(tester).style;
      print('Purple TextField.style.color = ${purpleStyle?.color}');
      print('Purple cs.primary            = ${_purple.colorScheme.primary}');
      expect(
        purpleStyle?.color,
        equals(_purple.colorScheme.primary),
        reason: 'inputStyle.color must equal cs.primary for the purple theme',
      );

      await pumpField(tester, _teal);
      await tester.pump();
      final tealStyle = _textField(tester).style;
      print('Teal   TextField.style.color = ${tealStyle?.color}');
      print('Teal   cs.primary            = ${_teal.colorScheme.primary}');
      expect(
        tealStyle?.color,
        equals(_teal.colorScheme.primary),
        reason: 'inputStyle.color must equal cs.primary for the teal theme',
      );

      expect(purpleStyle?.color, isNot(equals(tealStyle?.color)));
    });

    testWidgets(
      'scope subtree survives a breakpoint crossing (no remount flash)',
      (tester) async {
        // Start at 400 px (below mobile). pack.themeSpec is null there, so
        // themeData is null. Then jump to 1000 px (tablet) where
        // @bp.tablet.theme kicks in. If the scope conditionally wrapped in
        // Theme, this crossing would remount the entire subtree — erasing
        // the dropdown's items cache and causing the visible "flash" the
        // user reported.

        tester.view.physicalSize = const Size(2400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        double width = 400;
        late StateSetter setOuter;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (ctx, ss) {
              setOuter = ss;
              return MaterialApp(
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: Theme(
                        data: _purple,
                        child: TomFormStyleScope(
                          tomId: 'demo10Form',
                          style: const TomFormStyle(),
                          child: Builder(builder: (_) => form.name.widget),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Capture the TextField's Element identity at 400 px.
        final initialElement = tester.element(find.byType(TextField));

        // Cross mobile (600) and tablet (900) breakpoints in one jump.
        setOuter(() => width = 1000);
        await tester.pumpAndSettle();

        final afterElement = tester.element(find.byType(TextField));
        expect(
          identical(initialElement, afterElement),
          isTrue,
          reason:
              'The TextField element must be preserved across a bp crossing — '
              'if the scope conditionally adds/removes a Theme wrapper, '
              'Flutter would remount the subtree and lose this identity.',
        );
      },
    );

    testWidgets(
      'floating-label colour (InputDecoration.floatingLabelStyle) follows cs.primary',
      (tester) async {
        tester.view.physicalSize = const Size(600, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await pumpField(tester, _purple);
        await tester.pump();
        final purpleFloating = _textField(
          tester,
        ).decoration!.floatingLabelStyle;
        print('Purple floatingLabelStyle.color = ${purpleFloating?.color}');
        expect(
          purpleFloating?.color,
          equals(_purple.colorScheme.primary),
          reason:
              'floatingLabelStyle.color must equal cs.primary (floating label '
              'is visible when field has a value)',
        );

        await pumpField(tester, _teal);
        await tester.pump();
        final tealFloating = _textField(tester).decoration!.floatingLabelStyle;
        print('Teal   floatingLabelStyle.color = ${tealFloating?.color}');
        expect(tealFloating?.color, equals(_teal.colorScheme.primary));
        expect(purpleFloating?.color, isNot(equals(tealFloating?.color)));
      },
    );
  });
}
