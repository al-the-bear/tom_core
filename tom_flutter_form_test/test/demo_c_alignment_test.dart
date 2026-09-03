/// Pins the "top-aligned row keeps phone at the top when email has an
/// error below" behaviour reported in Demo C.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/forms/customer_form.dart';
import 'package:tom_flutter_form_test/state/phase1_state.dart';

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

  testWidgets('phone stays top-aligned when email shows an error below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final form = TomScope.withScope('demoC', () => CustomerForm());
    form.bind(phase1CustomerState);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomFormStyleScope(
            style: TomFormStyle.material3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) =>
                    TomAclBuilder(id: 'demoCTop', elementProvider: form)
                        .setAclExpandXDefault(true)
                        .append((p) => p.email.widget)
                        .append((p) => p.phone.widget, dist: 16)
                        .build(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Force email into an error state by clearing the required value.
    form.email.setValue('');
    await form.email.validate();
    await tester.pumpAndSettle();

    // Locate each field's TextField by controller text.
    final allFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    final phoneField = allFields.firstWhere(
      (t) => t.controller?.text == '+1 555 0100',
    );
    // Blank email now, so the controller text is empty — find by elimination.
    final emailField = allFields.firstWhere((t) => t.controller?.text == '');

    final emailTop = tester.getTopLeft(find.byWidget(emailField)).dy;
    final phoneTop = tester.getTopLeft(find.byWidget(phoneField)).dy;
    // ignore: avoid_print
    debugPrint('email.input.top = $emailTop, phone.input.top = $phoneTop');

    // Both input rows should share the same top (they sit under label,
    // which has the same height on both sides).
    expect(
      phoneTop,
      closeTo(emailTop, 0.5),
      reason:
          'With row-default top alignment, phone.input and email.input '
          'should sit at the same Y. If phone drifts down, the Row is '
          'centring despite AclRowCrossAlignment.top.',
    );
  });
}
