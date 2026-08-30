// [ListFormHost] contract: the two list-bearing groups get a list form that is
// both created inside its scope AND bound to the seeded items.
//
// The smoke tests only assert that each group renders without throwing, which
// an unbound list form does perfectly well — it just renders zero rows. These
// tests pin the binding itself, because that is the step [ListFormHost] owns on
// the groups' behalf: a regression that dropped the `bind` call would be
// invisible to every other test in the suite.

import 'package:core_flutter_form_showcase/common/chrome_texts.dart';
import 'package:core_flutter_form_showcase/common/showcase_section.dart';
import 'package:core_flutter_form_showcase/groups/lists_group.dart';
import 'package:core_flutter_form_showcase/groups/master_detail_group.dart';
import 'package:core_flutter_form_showcase/reflection_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(chromeTexts),
    );
  });

  Future<void> pumpGroup(WidgetTester tester, ShowcaseGroup group) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: GroupScreen(group: group)));
    await tester.pump();
  }

  testWidgets('lists group renders the seeded rows through ListFormHost',
      (tester) async {
    await pumpGroup(tester, listsGroup);

    // seededOrderItems() supplies three rows, each rendering a product-name and
    // a quantity field. Matching on `textContaining` rather than `text` because
    // the product-name field applies a display transform — it renders
    // "Difference Engine pinion  —  $34.50", not the bare name.
    for (final product in const [
      'Difference Engine pinion',
      'Punched-card deck (1000 pk)',
      'Lubricating oil (1L)',
    ]) {
      expect(find.textContaining(product), findsWidgets,
          reason: 'seeded row "$product" did not reach the screen');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('master-detail group binds its list through ListFormHost',
      (tester) async {
    await pumpGroup(tester, masterDetailGroup);

    // The master pane's header prints the bound list's length, so this asserts
    // the seeded count rather than merely that something rendered.
    expect(find.text('Items (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
