/// Diagnostic: mount the comprehensive_form demo and log any render
/// overflows + measure the widths of its top-row components so we can
/// see where the 3397 px overflow reported in the engine comes from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';

void main() {
  testWidgets('comprehensive_form at 1280 wide — probe overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1280,
          height: 900,
          child: const ComprehensiveFormDemo(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Collect all RenderFlex overflow exceptions.
    var flexWidths = <double>[];
    final error = tester.takeException();
    if (error != null) {
      // ignore: avoid_print
      print('TakeException: $error');
    }
    // ignore: avoid_print
    print('flexWidths=$flexWidths');
  });
}
