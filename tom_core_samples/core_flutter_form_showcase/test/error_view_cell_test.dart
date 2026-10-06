// The TomErrorView cell populates when the reader does what its note says.
//
// An error summary is empty until validation runs, so a cell holding only the
// summary would render an empty preview, with no way for the reader to run
// validation. The cell carries the field and a Validate button, and this holds
// it to the note that tells the reader to press it.

import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/common/showcase_cell.dart';
import 'package:core_flutter_form_showcase/common/showcase_section.dart';
import 'package:core_flutter_form_showcase/groups/validation_group.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(showcaseTexts),
    );
  });

  testWidgets('EV-1: pressing Validate fills the error summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: GroupScreen(group: validationGroup)),
    );
    await tester.pump();

    final cell = find.byWidgetPredicate(
      (w) => w is ShowcaseCell && w.title == 'TomErrorView summary',
    );
    final summary = find.descendant(
      of: cell,
      matching: find.text('Please fix the following'),
    );
    expect(summary, findsNothing, reason: 'empty until validation runs');

    await tester.tap(
      find.descendant(of: cell, matching: find.text('Validate')),
    );
    // The form's async tax-ID check takes 600 ms of simulated time.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(summary, findsOneWidget);
  });
}
