/// Regression guard for Demo H, mirroring [demo_g_focus_test.dart].
///
/// Demo H originally mixed in `TomFormEventListener` and called
/// `setState(() {})` on the full demo subtree in `onFieldValueChanged`, so
/// every keystroke rebuilt the entire tree — including the
/// `TomFormStyleScope` and its themed descendants — which wiped the
/// `TextField`'s `FocusNode`. The listener was dropped: the field-state
/// table rebuilds itself via its own `ListenableBuilder` on
/// `form.changes`, and the auth dropdowns already carry their own
/// `setState` inside `_setAuth`.
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

  testWidgets('Demo H title field keeps focus across multiple keypresses',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo H: Complex Authorization Scenarios'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo H: Complex Authorization Scenarios'));
    await tester.pumpAndSettle();

    final titleField = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere(
            (t) => t.controller?.text == 'Responsive dashboard refresh');

    await tester.tap(find.byWidget(titleField));
    await tester.pumpAndSettle();
    expect(titleField.focusNode?.hasFocus, isTrue,
        reason: 'Tap should give the title field focus.');

    await tester.enterText(find.byWidget(titleField),
        '${titleField.controller?.text}!!!');
    await tester.pumpAndSettle();

    expect(titleField.controller?.text, 'Responsive dashboard refresh!!!');
    expect(titleField.focusNode?.hasFocus, isTrue,
        reason: 'Typing must not unfocus the field.');
  });
}
