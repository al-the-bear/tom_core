/// Behavioural coverage for `TomSkeletonLoader`, concentrated on what
/// `enabled: false` actually leaves on screen.
///
/// The interesting property is not that the animation stops — it is *where
/// the two forms of the widget stop*. `enabled: false` removes the
/// `ShaderMask` rather than freezing it, and the mask is what paints the
/// skeleton, so the childless form keeps the rectangle it draws itself while
/// the `child` form comes back in the caller's own colours.
///
/// That asymmetry is invisible from the call site and was documented away for
/// a long time as "renders a static rectangle". It is invisible while
/// `enabled` is true, too, which is what made it durable: the mask overpaints
/// a child's colours, so a red child shimmers grey exactly like every other
/// skeleton and only reveals itself as red once disabled.
///
/// The assertions below are therefore about **painted pixels**, not widget
/// types. A `find.byType(ShaderMask)` check cannot distinguish the two cases:
/// neither has a mask when disabled, which is precisely why the pre-existing
/// check in `custom_example_test.dart` passed throughout.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

const Key _boundary = Key('skeleton-boundary');

/// Wraps [child] in a repaint boundary so the rendered result can be read
/// back as pixels.
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: _boundary, child: child),
        ),
      ),
    );

/// The colour actually painted at the centre of the hosted widget.
///
/// Rendering to an image is the only way to see through a `ShaderMask`: the
/// mask is a compositing effect, so the child's widget tree is unchanged by
/// it and no finder can report what colour ended up on screen.
Future<ui.Color> _centrePixel(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  late ui.Image image;
  late ByteData bytes;
  await tester.runAsync(() async {
    image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
  return ui.Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

/// Compares two colours by their 8-bit channels.
///
/// The sampled pixel is reconstructed from raw bytes, so it is only ever
/// channel-accurate; comparing `Color` objects directly would also compare
/// colour space and floating-point components that survived a different
/// route.
Matcher _sameColourAs(Color expected) => predicate<ui.Color>(
      (actual) =>
          (actual.r * 255).round() == (expected.r * 255).round() &&
          (actual.g * 255).round() == (expected.g * 255).round() &&
          (actual.b * 255).round() == (expected.b * 255).round(),
      'the same RGB as $expected',
    );

void main() {
  group('TomSkeletonLoader enabled: false', () {
    testWidgets('without a child, the coloured rectangle remains',
        (tester) async {
      // The half the old documentation described correctly.
      await tester.pumpWidget(_host(const TomSkeletonLoader(
        enabled: false,
        width: 40,
        height: 40,
        baseColor: Colors.green,
      )));
      await tester.pump();

      expect(await _centrePixel(tester), _sameColourAs(Colors.green),
          reason: 'the widget draws this rectangle itself, so dropping the '
              'mask leaves it standing — a static placeholder');
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('with a child, the child keeps its own colours',
        (tester) async {
      // The half it did not. Nothing is painted over the child at all: it is
      // returned exactly as passed, which is a placeholder only if the caller
      // supplied one.
      await tester.pumpWidget(_host(TomSkeletonLoader(
        enabled: false,
        child: Container(width: 40, height: 40, color: Colors.red),
      )));
      await tester.pump();

      expect(await _centrePixel(tester), _sameColourAs(Colors.red),
          reason: 'no grey box is drawn and no mask is applied — the caller '
              "gets their own widget back, not a placeholder");
    });

    testWidgets('a child that is real content is rendered as real content',
        (tester) async {
      // Stated separately from the colour case because this is the
      // consequence that matters to a reduced-motion caller: the setting
      // they reach for to stop the animation also stops the skeleton.
      await tester.pumpWidget(_host(const TomSkeletonLoader(
        enabled: false,
        child: Text('real-content'),
      )));
      await tester.pump();

      expect(find.text('real-content'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('TomSkeletonLoader enabled: true', () {
    testWidgets('the mask overpaints the child, hiding its colours',
        (tester) async {
      // Without this, the test above is ambiguous: "the child is red when
      // disabled" could just mean the child is always red, making the
      // disabled case unremarkable. It is remarkable because the enabled
      // case is *not* red — which is also why the asymmetry stayed hidden.
      await tester.pumpWidget(_host(TomSkeletonLoader(
        child: Container(width: 40, height: 40, color: Colors.red),
      )));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(await _centrePixel(tester), isNot(_sameColourAs(Colors.red)),
          reason: 'srcATop keeps the silhouette and replaces the colours, so '
              'a red child shimmers grey like any other skeleton');
    });
  });

  group('TomSkeletonLoader toggling', () {
    testWidgets('disabling removes the mask rather than freezing it',
        (tester) async {
      // The dartdoc claims removal, not suspension. A frozen mask would keep
      // overpainting the child with whatever gradient phase it stopped on,
      // which is a different — and much less surprising — behaviour than the
      // one this widget actually has.
      Widget at(bool enabled) => _host(TomSkeletonLoader(
            enabled: enabled,
            child: Container(width: 40, height: 40, color: Colors.red),
          ));

      await tester.pumpWidget(at(true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(await _centrePixel(tester), isNot(_sameColourAs(Colors.red)));

      await tester.pumpWidget(at(false));
      await tester.pump();

      expect(find.byType(ShaderMask), findsNothing);
      expect(await _centrePixel(tester), _sameColourAs(Colors.red),
          reason: 'the colours come back, so the mask is gone and not merely '
              'stopped');
    });
  });
}
