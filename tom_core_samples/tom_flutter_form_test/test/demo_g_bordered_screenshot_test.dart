/// Diagnostic captures for the ≥1600 bordered band: one crop per field
/// type so the floating-label / border interaction can be inspected at
/// real pixel density (not a thumbnail of the whole page).
///
/// The test bypasses the DemoListScreen navigation and pumps the form
/// pane directly at a fixed 1728 px width (bordered band). It also pumps
/// both the current `_borderedRoomy` variant and the raw
/// `TomFormStyle.bordered` at the same theme so the diff is isolated.
///
/// Run with:
///   flutter test test/demo_g_bordered_screenshot_test.dart --update-goldens
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/forms/project_brief_form.dart';
import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/project_brief_state.dart';

import 'support/test_fonts.dart';

ThemeData _mkBlueSerifXl() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    fontFamily: 'serif',
  );
  final cs = base.colorScheme;
  TextStyle ink(TextStyle? s, double size) =>
      (s ?? const TextStyle()).copyWith(fontSize: size, color: cs.primary);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodySmall: ink(base.textTheme.bodySmall, 16),
      bodyMedium: ink(base.textTheme.bodyMedium, 18),
      bodyLarge: ink(base.textTheme.bodyLarge, 20),
      titleSmall: ink(base.textTheme.titleSmall, 19),
    ),
  );
}

Widget _buildHarness({
  required ProjectBriefForm form,
  required TomFormStyle style,
  required String tag,
}) {
  return MaterialApp(
    theme: _mkBlueSerifXl(),
    home: Material(
      child: TomFormStyleScope(
        style: style,
        theme: _mkBlueSerifXl(),
        // Padding above and below the pane so the first field's floating
        // label (which draws slightly above the field's top edge) and the
        // last field's description (which draws below) are both fully
        // inside the crop.
        child: Padding(
          padding: const EdgeInsets.all(80),
          child: RepaintBoundary(
            key: ValueKey('pane-$tag'),
            child: SizedBox(
              width: 1728,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  form.code.widget,
                  const SizedBox(height: 12),
                  form.title.widget,
                  const SizedBox(height: 12),
                  form.summary.widget,
                  const SizedBox(height: 12),
                  form.category.widget,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
    await loadTestFonts();
  });

  testWidgets('Bordered floating labels fit above the outline at 18 px theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1760, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final form = TomScope.withScope('demoG', () => ProjectBriefForm());
    form.bind(phase2ProjectBriefState);
    form.lead.bind(phase2ProjectBriefState.lead);
    form.reviewer.bind(phase2ProjectBriefState.reviewer);

    await tester.pumpWidget(
      _buildHarness(form: form, style: TomFormStyle.bordered, tag: 'raw'),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('pane-raw')),
      matchesGoldenFile('goldens/demo_g_bordered_fixed_preset.png'),
    );
  });

  testWidgets('Full Demo G at ≥1600 — real navigation path', (tester) async {
    tester.view.physicalSize = const Size(3200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.tap(find.text('Demo G: Complex Breakpoint Scenarios'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo_g_full_bordered.png'),
    );
  });
}
