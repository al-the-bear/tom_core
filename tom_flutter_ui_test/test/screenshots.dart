/// Screenshot harness for every demo in the tom_flutter_ui_test app.
///
/// Run with: `flutter test test/screenshots.dart`
///
/// Why this is `screenshots.dart`, not `screenshots_test.dart`: this is a
/// manual PNG-generation tool, not a regression gate. It mounts each demo in
/// a deliberately minimal, fixed-size, offline capture box — without the
/// scrolling, `TomScope`/resource bindings, or `PrimaryScrollController` the
/// real two-tab app provides — so demos that need that scaffolding render
/// overflow banners / broken-image placeholders / resource errors. Those are
/// capture-context artifacts, not `tom_flutter_ui` regressions, so the harness
/// must not gate the default `flutter test`. Dropping the `_test.dart` suffix
/// keeps it out of the auto-discovered suite while leaving it runnable on
/// demand via the command above.
///
/// Each demo is mounted in a fixed-size viewport, pumped once, and captured
/// via `RenderRepaintBoundary.toImage()`. PNGs are written to
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';
import 'package:tom_flutter_ui_test/demo_resources.dart';
import 'package:tom_flutter_ui_test/forms_demos/forms_demos.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_01_buttons.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_02_inputs.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_03_selection.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_04_toggles.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_05_sliders.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_06_cards_panels.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_07_layout.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_08_scrollable.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_09_dialogs.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_10_tables.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_11_labels.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_12_images.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_13_navigation.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_14_progress.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_15_lists.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_16_trees.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_17_slivers.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_18_animated.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_19_effects.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_20_interactions.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_21_resource_resolution.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_22_extension_widgets.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_23_builders_clips.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_24_containers_layout.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_25_remaining_widgets.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_26_scope_action.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_27_forms.dart';
import 'package:tom_flutter_ui_test/widget_demos/demo_28_authorization.dart';

/// `(slug, demoFactory)` — slug is used as the PNG filename.
///
/// Order follows the sidebar in main.dart so screenshots are easy to scan.
final List<(String, Widget Function())> _demos = [
  ('acl_01_basic_row', () => BasicRowDemo()),
  ('acl_02_multi_row', () => MultiRowDemo()),
  ('acl_03_alignment', () => AlignmentDemo()),
  ('acl_04_all_dimensions', () => AllDimensionsDemo()),
  ('acl_05_expand', () => ExpandDemo()),
  ('acl_06_spacing', () => SpacingDemo()),
  ('acl_07_size_constraints', () => SizeConstraintsDemo()),
  ('acl_08_reference_constraints', () => ReferenceConstraintsDemo()),
  ('acl_09_convenience_placement', () => ConveniencePlacementDemo()),
  ('acl_10_mixed_placement_playground',
      () => MixedPlacementPlaygroundDemo()),
  ('acl_11_responsive_convenience', () => ResponsiveConvenienceDemo()),
  ('acl_12_character_width_sizing', () => CharacterWidthSizingDemo()),
  ('acl_13_border_styles', () => BorderStylesDemo()),
  ('acl_14_groups', () => GroupsDemo()),
  ('acl_15_bordered_groups', () => BorderedGroupsDemo()),
  ('acl_16_nested_containers', () => NestedContainersDemo()),
  ('acl_17_form_layout', () => FormLayoutDemo()),
  ('acl_18_complex_layout', () => ComplexLayoutDemo()),
  ('acl_19_comprehensive_form', () => ComprehensiveFormDemo()),
  ('acl_20_dynamic_resize', () => DynamicResizeDemo()),
  ('acl_21_fluent_api', () => FluentApiDemo()),
  ('acl_22_group_visibility', () => GroupVisibilityDemo()),
  ('acl_23_responsive_variants', () => ResponsiveVariantsDemo()),
  ('acl_24_row_breakpoints', () => RowBreakpointsDemo()),
  ('acl_25_breakpoint_expansion', () => BreakpointExpansionDemo()),
  ('acl_26_inline_variants', () => InlineVariantsDemo()),
  ('widget_01_buttons', () => ButtonsDemo()),
  ('widget_02_inputs', () => InputsDemo()),
  ('widget_03_selection', () => SelectionDemo()),
  ('widget_04_toggles', () => ToggleDemo()),
  ('widget_05_sliders', () => SliderDemo()),
  ('widget_06_cards_panels', () => CardPanelDemo()),
  ('widget_07_layout', () => LayoutContainersDemo()),
  ('widget_08_scrollable', () => ScrollableContainersDemo()),
  ('widget_09_dialogs', () => DialogModalGalleryDemo()),
  ('widget_10_tables', () => DataTablesDemo()),
  ('widget_11_labels', () => LabelsDemo()),
  ('widget_12_images', () => ImagesDemo()),
  ('widget_13_navigation', () => NavigationDemo()),
  ('widget_14_progress', () => ProgressDemo()),
  ('widget_15_lists', () => ListsDemo()),
  ('widget_16_trees', () => TreesDemo()),
  ('widget_17_slivers', () => SliversDemo()),
  ('widget_18_animated', () => AnimatedDemo()),
  ('widget_19_effects', () => EffectsDemo()),
  ('widget_20_interactions', () => InteractionsDemo()),
  ('widget_21_resource_resolution', () => ResourceResolutionDemo()),
  ('widget_22_extension_widgets', () => ExtensionWidgetsDemo()),
  ('widget_23_builders_clips', () => BuildersClipsDemo()),
  ('widget_24_containers_layout', () => ContainersLayoutDemo()),
  ('widget_25_remaining_widgets', () => RemainingWidgetsDemo()),
  ('widget_26_scope_action', () => ScopeActionDemo()),
  ('forms_01_forms', () => FormsDemo()),
  ('forms_02_forms_overview', () => FormsOverviewDemo()),
  ('auth_01_authorization', () => AuthorizationDemo()),
];

/// Logical viewport for the demo capture. 1280 wide matches a typical
/// desktop breakpoint for the two-column layouts in the forms/auth demos;
/// 2400 tall leaves room for the long scrollable demos (reference
/// constraints, comprehensive form, etc.) to render their full content
/// without clipping so the resulting PNG can be inspected in one piece.
const Size _viewport = Size(1280, 2400);

/// Pixel ratio for the captured image. 1.0 keeps PNGs small and exactly
/// matches logical pixels in assertions.
const double _pixelRatio = 1.0;

Future<void> _capture({
  required WidgetTester tester,
  required Widget demo,
  required String slug,
}) async {
  final captureKey = GlobalKey(debugLabel: 'screenshot-$slug');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: SizedBox.fromSize(
          size: _viewport,
          child: RepaintBoundary(
            key: captureKey,
            child: Material(child: demo),
          ),
        ),
      ),
    ),
  );

  // Settle pending animations/layout. Cap with a timeout so an animated
  // demo that never idles does not block the run.
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
  } on FlutterError {
    // Some demos run perpetual animations (progress indicators, etc.).
    // Fall back to a few plain pumps so we still capture a frame.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final boundary = captureKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  // Why: RenderRepaintBoundary.toImage() and Image.toByteData() complete only
  // once the engine's raster thread finishes the GPU work — real async that
  // the fake-async zone driving testWidgets never advances, so awaiting them
  // directly deadlocks until the 10-minute per-test timeout. runAsync() runs
  // the body against the real event loop, which is the supported path for
  // rasterising a boundary inside a widget test (the same one Flutter's
  // golden machinery uses).
  final byteData = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data;
  });
  if (byteData == null) {
    fail('toByteData returned null for $slug');
  }

  final outDir = Directory('test/screenshots');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final file = File('${outDir.path}/$slug.png');
  file.writeAsBytesSync(byteData.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Match main.dart's bootstrap so TomText resources resolve correctly.
    initializeDemoResources();
  });

  // Pump each demo in its own test so failures are isolated.
  for (final (slug, factory) in _demos) {
    testWidgets('screenshot · $slug', (tester) async {
      tester.view.physicalSize = _viewport * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        await _capture(tester: tester, demo: factory(), slug: slug);
      } on FlutterError catch (e) {
        // Surface the demo's own overflow errors without aborting the run,
        // but still mark the individual screenshot as failed.
        final messages = tester.takeException();
        fail('Demo $slug threw: ${e.message}\nCaught: $messages');
      }
    });
  }
}
