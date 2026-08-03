/// Screenshot harness for every demo in the tom_flutter_ui_test app.
///
/// Run with: `flutter test test/screenshots.dart`
///
/// Why this is `screenshots.dart`, not `screenshots_test.dart`: it is a manual
/// PNG-generation tool, not a regression gate. It asserts nothing about what a
/// demo *should* look like — it writes a picture for a human to look at. A
/// suite that always passes has no business in the gating run, and dropping the
/// `_test.dart` suffix keeps it out of the auto-discovered suite while leaving
/// it runnable on demand via the command above.
///
/// The mount itself — scope, fonts, offline images, scroll controller, viewport
/// — lives in `demo_harness.dart`, shared with `demo_overflow_test.dart`. That
/// file is the one to read for *why* the capture box looks the way it does.
/// The gate is where layout faults are caught; here, an overflow is merely
/// reported, because Flutter paints the striped banner and the PNG is then the
/// clearest possible record of the problem.
///
/// One thing differs between the two suites: this one mounts with the **real
/// SDK fonts** and the gate mounts with **Ahem**. So a PNG here shows the app's
/// true metrics, while the gate measures the harsher Ahem ones. Expect the gate
/// to be the stricter of the two; a demo that passes it has slack left over
/// under Roboto.
///
/// Each demo is mounted, pumped, and captured via
/// `RenderRepaintBoundary.toImage()`. PNGs are written to
/// `test/screenshots/<demo>.png`. This is the same capture path that Flutter's
/// golden tests use internally, so it works headlessly without any extra
/// dependencies. The rasterisation runs inside `tester.runAsync()` because
/// `toImage()`/`toByteData()` complete only on the engine's real event loop.
///
/// Intended use: any time a demo is rebuilt or a layout primitive changes,
/// rerun this file and diff the PNGs to see the visual impact.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_harness.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Real fonts: the whole point of a PNG is that a human reads it, and Ahem
  // renders every label as a black box. The overflow gate deliberately runs
  // with the opposite setting — see installDemoEnvironment.
  setUpAll(() => installDemoEnvironment(binding, realFonts: true));
  tearDownAll(() => restoreDemoEnvironment(binding));

  // Capture each demo in its own test so failures are isolated.
  for (final (slug, _) in demos) {
    testWidgets('screenshot · $slug', (tester) async {
      final DemoMount mount;
      try {
        mount = await pumpDemo(tester, slug);
      } on FlutterError catch (e) {
        // Surface the demo's own errors without aborting the run, but still
        // mark the individual screenshot as failed.
        final messages = tester.takeException();
        fail('Demo $slug threw: ${e.message}\nCaught: $messages');
      }

      final boundary = mount.captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Why: RenderRepaintBoundary.toImage() and Image.toByteData() complete
      // only once the engine's raster thread finishes the GPU work — real async
      // that the fake-async zone driving testWidgets never advances, so
      // awaiting them directly deadlocks until the 10-minute per-test timeout.
      // runAsync() runs the body against the real event loop, which is the
      // supported path for rasterising a boundary inside a widget test (the
      // same one Flutter's golden machinery uses).
      final byteData = await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data;
      });
      if (byteData == null) {
        fail('toByteData returned null for $slug');
      }

      final outDir = Directory('test/screenshots');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      File('${outDir.path}/$slug.png')
          .writeAsBytesSync(byteData.buffer.asUint8List());

      for (final overflow in mount.overflows) {
        debugPrint('screenshot · $slug: $overflow (see the banner in the PNG)');
      }
    });
  }
}
