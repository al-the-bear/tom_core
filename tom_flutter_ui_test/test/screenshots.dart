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
/// The capture box reproduces the parts of the real two-tab app that a demo can
/// legitimately depend on, so a demo renders here as it does in the app:
///
/// - **[TomScope]** — `main.dart` constructs each widget demo inside
///   `TomScope.withScope('demoNN', …)`, which is what its resource keys resolve
///   against. [_scopeIdFor] reproduces that mapping; without it a
///   resource-driven demo throws rather than rendering.
/// - **Real fonts** — [_loadSdkFonts] replaces the Ahem placeholder that
///   `flutter test` installs, so labels are readable rather than black boxes.
/// - **[PrimaryScrollController]** — a `Scrollbar` defaults to the primary
///   controller and asserts if it has no attached position. In the app the
///   route supplies one; here the harness does.
/// - **Offline images** — [_OfflineHttpOverrides] answers every network image
///   request with a 1×1 transparent PNG, so a demo that loads a remote asset
///   captures a clean frame instead of a broken-image placeholder (and the run
///   stays hermetic).
/// - **A stubbed sensitive-content channel** — `SensitiveContent` caches a
///   platform capability query and asserts on teardown that it arrived; with no
///   platform behind the channel it never does.
/// - **A definite box** — the capture box is [_viewport]-sized in *both* axes.
///   Letting it grow vertically (a scroll view) would look like the friendlier
///   choice for a long demo, but it hands the demo an unbounded height, which
///   the ACL layout engine cannot size rows against. The viewport is deliberately
///   tall instead.
///
/// Overflow is reported, not fatal: a demo that overflows the viewport still
/// captures, because Flutter paints the striped banner and the PNG is then the
/// clearest possible record of the problem. See [_isOverflowReport].
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
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

/// Demo slugs whose scope id does not follow the `widget_NN` → `demoNN` rule.
///
/// The forms and authorization demos appear in a different tab from the widget
/// gallery but are still constructed inside a `demoNN` scope by `main.dart`.
const Map<String, String> _scopeIdOverrides = {
  'forms_01_forms': 'demo27',
  'auth_01_authorization': 'demo28',
};

/// The [TomScope] id a demo must be constructed in, or null for an unscoped one.
///
/// `main.dart` wraps each widget-gallery demo in `TomScope.withScope('demoNN')`
/// and leaves the ACL demos unscoped; the resource keys the demos use are
/// written against exactly that. Reproducing the mapping here is what makes a
/// resource-driven demo resolve the same values it resolves in the app.
String? _scopeIdFor(String slug) {
  final override = _scopeIdOverrides[slug];
  if (override != null) return override;
  final match = RegExp(r'^widget_(\d{2})_').firstMatch(slug);
  return match == null ? null : 'demo${match.group(1)}';
}

/// Serves every image request a demo makes with a 1x1 transparent PNG.
///
/// Keeps the harness hermetic (no network in a test run) and stops a remote
/// asset from capturing as a broken-image placeholder.
class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineHttpClient();
}

/// The smallest valid PNG: one fully transparent pixel.
final Uint8List _transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Every stub below implements only what `NetworkImage` actually touches and
/// answers the rest through `noSuchMethod`. `autoUncompress` is spelled out
/// because the image loader reads it as a `bool` and would choke on a null.
class _OfflineHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _OfflineRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _OfflineRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _OfflineRequest implements HttpClientRequest {
  _OfflineRequest(this.uri);

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _EmptyHeaders();

  @override
  Future<HttpClientResponse> close() async => _OfflineResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _OfflineResponse implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentPixelPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _EmptyHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPixelPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _EmptyHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Replaces the test-only Ahem font with the real Roboto and Material Icons.
///
/// Why: `flutter test` ships a single placeholder font that paints every glyph
/// as a filled box. That is the right default for a golden *comparison* — it is
/// deterministic across machines — but this harness exists to produce a picture
/// a human reads, and a page of black rectangles is not one. The fonts come out
/// of the Flutter SDK, so no asset is added to this package.
///
/// Degrades rather than fails: if the SDK cache is not where it is expected,
/// the run continues with Ahem and says so.
Future<void> _loadSdkFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final dir = root == null
      ? null
      : Directory('$root/bin/cache/artifacts/material_fonts');
  if (dir == null || !dir.existsSync()) {
    debugPrint('screenshots: SDK fonts not found; capturing with the Ahem '
        'placeholder font.');
    return;
  }

  Future<void> loadFamily(String family, List<String> fileNames) async {
    final loader = FontLoader(family);
    var added = 0;
    for (final name in fileNames) {
      final file = File('${dir.path}/$name');
      if (!file.existsSync()) continue;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
      );
      added++;
    }
    if (added > 0) await loader.load();
  }

  await loadFamily('Roboto', const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
    'Roboto-Italic.ttf',
  ]);
  await loadFamily('MaterialIcons', const ['MaterialIcons-Regular.otf']);
}

/// True for the "A RenderFlex overflowed by N pixels" layout report.
///
/// Why it is singled out: an overflow is *visible* — Flutter paints the striped
/// banner — so the PNG this harness writes already carries the finding. Failing
/// on it would suppress the very picture that shows it, so [_capture] collects
/// these and lets the capture proceed.
bool _isOverflowReport(FlutterErrorDetails details) =>
    details.library == 'rendering library' &&
    details.exception.toString().contains('overflowed by');

Future<void> _capture({
  required WidgetTester tester,
  required Widget demo,
  required String slug,
}) async {
  final captureKey = GlobalKey(debugLabel: 'screenshot-$slug');
  // A Scrollbar resolves the primary controller and asserts if it has no
  // attached position; in the app the enclosing route supplies one.
  final primaryController = ScrollController();
  addTearDown(primaryController.dispose);

  final overflows = <String>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isOverflowReport(details)) {
      overflows.add(details.exception.toString().split('\n').first);
      return;
    }
    priorOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = priorOnError);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: PrimaryScrollController(
          controller: primaryController,
          // Definite in both axes. A tempting alternative — wrapping in a
          // SingleChildScrollView so a long demo grows instead of overflowing —
          // hands the demo an *unbounded* height, and the ACL layout engine
          // sizes its rows against a finite constraint; it cannot lay out
          // without one. The viewport is generously tall instead.
          child: SizedBox.fromSize(
            size: _viewport,
            child: RepaintBoundary(
              key: captureKey,
              child: Material(child: demo),
            ),
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

  for (final overflow in overflows.toSet()) {
    debugPrint('screenshot · $slug: $overflow (see the banner in the PNG)');
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Match main.dart's bootstrap so TomText resources resolve correctly.
    initializeDemoResources();
    await _loadSdkFonts();
    HttpOverrides.global = _OfflineHttpOverrides();
    // Why: SensitiveContent asks the platform whether content sensitivity is
    // supported and caches the answer; unregister asserts that the answer has
    // arrived. With no handler the query never completes, so tearing the demo
    // down at end of test trips that assert. Answering "not supported" is the
    // truthful reply for the desktop host this harness runs on.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.sensitiveContent,
      (call) async =>
          call.method == 'SensitiveContent.isSupported' ? false : null,
    );
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.sensitiveContent, null);
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

      // The demo must be *constructed* inside its scope: TomNodeBase resolves
      // its resource base path in the constructor, not in build.
      final scopeId = _scopeIdFor(slug);
      final demo =
          scopeId == null ? factory() : TomScope.withScope(scopeId, factory);

      try {
        await _capture(tester: tester, demo: demo, slug: slug);
      } on FlutterError catch (e) {
        // Surface the demo's own errors without aborting the run, but still
        // mark the individual screenshot as failed.
        final messages = tester.takeException();
        fail('Demo $slug threw: ${e.message}\nCaught: $messages');
      }
    });
  }
}
