/// Regression guard: typing multiple characters into a Demo G field
/// keeps focus. A `_ComplexFormBody` that read `Theme.of(context)` at its
/// root for a decorative background Container would lose it: theme changes
/// from fresh ThemeData instances handed in at every build cascade a full
/// subtree rebuild, which wipes the TextField's FocusNode after the
/// first typed character.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  testWidgets('Demo G title field keeps focus across multiple keypresses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.tap(find.text('Demo G: Complex Breakpoint Scenarios'));
    await tester.pumpAndSettle();

    // Locate the title field via its pre-bound value, focus it, then type.
    final titleField = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere(
          (t) => t.controller?.text == 'Responsive dashboard refresh',
        );

    await tester.tap(find.byWidget(titleField));
    await tester.pumpAndSettle();
    expect(
      titleField.focusNode?.hasFocus,
      isTrue,
      reason: 'Tap should give the title field focus.',
    );

    // Type three characters. If focus were lost after the first one,
    // only the first character would land.
    await tester.enterText(
      find.byWidget(titleField),
      '${titleField.controller?.text}!!!',
    );
    await tester.pumpAndSettle();

    expect(titleField.controller?.text, 'Responsive dashboard refresh!!!');
    expect(
      titleField.focusNode?.hasFocus,
      isTrue,
      reason: 'Typing must not unfocus the field.',
    );
  });
}
