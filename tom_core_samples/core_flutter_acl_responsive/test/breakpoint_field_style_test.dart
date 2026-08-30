// Breakpoint-field-style tests: the same form re-styles itself per width tier.
//
// [BreakpointFieldStyleDemo] wraps the form in a [TomFormStyleScope] whose
// LayoutBuilder publishes the available width; a row of badges echoes the live
// resolution of each `*BpOverrides` property. Pumping the demo inside a
// fixed-width SizedBox pins the published width exactly, so the badge values are
// a deterministic ground truth for the tier the field style resolved to. Mirrors
// the verified `tom_flutter_form_test` `demo_8_breakpoints_test`.

import 'package:core_flutter_acl_responsive/groups/breakpoint_field_style_group.dart';
import 'package:core_flutter_acl_responsive/reflection_seed.dart';
import 'package:core_flutter_acl_responsive/common/chrome_texts.dart';
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

  /// Pump the demo inside a fixed-width SizedBox so its internal LayoutBuilder
  /// publishes exactly [width]. A tall viewport avoids vertical overflow noise.
  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Auxiliary field chrome can overflow at the very narrow widths; that's not
    // what these tests assert (the badge text is still computed and visible).
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: BreakpointFieldStyleDemo(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Read a single badge's value by its "label: value" text prefix.
  String badgeValue(String label) {
    final t = find
        .byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('$label:') ?? false),
        )
        .evaluate()
        .first
        .widget as Text;
    return t.data!.substring(label.length + 2); // strip "label: "
  }

  testWidgets('wide tier (800px) resolves the largest field anatomy',
      (tester) async {
    await pumpAtWidth(tester, 800);
    expect(badgeValue('labelPlacement'), 'inline');
    expect(badgeValue('labelStyle'), '15px');
    expect(badgeValue('hintStyle'), '15px');
    expect(badgeValue('labelFieldGap'), '8px');
    expect(badgeValue('errorFieldGap'), '8px');
    expect(badgeValue('errorBorderEnabled'), 'on');
    expect(badgeValue('errorIconEnabled'), 'on');
  });

  testWidgets('mid tier (450px) lands in the 400-499 band', (tester) async {
    await pumpAtWidth(tester, 450);
    expect(badgeValue('labelPlacement'), 'above');
    expect(badgeValue('labelStyle'), '13px');
    expect(badgeValue('labelFieldGap'), '4px');
    expect(badgeValue('errorBorderEnabled'), 'on');
    expect(badgeValue('errorIconEnabled'), 'off',
        reason: 'icon turns on only at 500px and we are at 450px');
  });

  testWidgets('narrow tier (360px) resolves the most compact anatomy',
      (tester) async {
    await pumpAtWidth(tester, 360);
    expect(badgeValue('labelPlacement'), 'floating');
    expect(badgeValue('labelStyle'), '11px');
    expect(badgeValue('labelFieldGap'), '2px');
    expect(badgeValue('errorBorderEnabled'), 'off',
        reason: 'border is off below 400px');
    expect(badgeValue('errorIconEnabled'), 'off',
        reason: 'icon is off below 500px');
  });
}
