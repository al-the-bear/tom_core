/// Shared machinery for mounting every demo the way the real app mounts it.
///
/// Two suites need exactly the same mount and differ only in what they do with
/// the result: `screenshots.dart` rasterises it into a PNG, and
/// `demo_overflow_test.dart` asserts that nothing overflowed. Keeping the mount
/// here means the picture a human inspects and the layout the gate measures can
/// never drift apart — if they could, the gate would be certifying a frame
/// nobody ever looks at.
///
/// The capture box reproduces the parts of the real two-tab app that a demo can
/// legitimately depend on, so a demo renders here as it does in the app:
///
/// - **[TomScope]** — `main.dart` constructs each widget demo inside
///   `TomScope.withScope('demoNN', …)`, which is what its resource keys resolve
///   against. [scopeIdFor] reproduces that mapping; without it a
///   resource-driven demo throws rather than rendering.
/// - **A chosen font** — see [installDemoEnvironment]'s `realFonts`. The two
///   suites deliberately disagree here, and that is the one axis on which they
///   are allowed to.
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
/// - **A definite box** — the capture box is [viewport]-sized in *both* axes.
///   Letting it grow vertically (a scroll view) would look like the friendlier
///   choice for a long demo, but it hands the demo an unbounded height, which
///   the ACL layout engine cannot size rows against. The viewport is
///   deliberately tall instead.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui_test/acl_demos/acl_demos.dart';
import 'package:tom_flutter_ui_test/demo_resources.dart';
import 'package:tom_flutter_ui_test/forms_demos/forms_demos.dart';
import 'package:tom_flutter_ui_test/forms_demos/phase2_demos.dart';
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

/// `(slug, demoFactory)` — slug names the demo in test output and PNG files.
///
/// Order follows the sidebar in main.dart so screenshots are easy to scan.
///
/// **This list must cover every screen the app can open.** Both the overflow
/// gate and the screenshot harness iterate it and nothing else, so an omitted
/// screen is not merely untested — it is skipped in silence by the two tools
/// whose whole job is to look at every screen. `demo_coverage_test.dart`
/// enforces the completeness by comparing this list against the `DemoTile`s
/// each tab actually builds, so adding a demo to `main.dart` and forgetting it
/// here now fails instead of going unnoticed.
final List<(String, Widget Function())> demos = [
  ('acl_01_basic_row', () => BasicRowDemo()),
  ('acl_02_multi_row', () => MultiRowDemo()),
  ('acl_03_alignment', () => AlignmentDemo()),
  ('acl_04_all_dimensions', () => AllDimensionsDemo()),
  ('acl_05_expand', () => ExpandDemo()),
  ('acl_06_spacing', () => SpacingDemo()),
  ('acl_07_size_constraints', () => SizeConstraintsDemo()),
  ('acl_08_reference_constraints', () => ReferenceConstraintsDemo()),
  ('acl_09_convenience_placement', () => ConveniencePlacementDemo()),
  ('acl_10_mixed_placement_playground', () => MixedPlacementPlaygroundDemo()),
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
  // The Phase-2 forms screens, in the order `FormsActionsTab` mounts them.
  ('forms_03_selection_variants', () => SelectionVariantsDemo()),
  ('forms_04_boolean_variants', () => BooleanVariantsDemo()),
  ('forms_05_complex_breakpoints', () => ComplexBreakpointsDemo()),
  ('forms_06_complex_auth', () => ComplexAuthDemo()),
  ('auth_01_authorization', () => AuthorizationDemo()),
];

/// Logical viewport every demo is mounted in.
///
/// 1280 wide matches a typical desktop breakpoint for the two-column layouts in
/// the forms/auth demos; 2400 tall leaves room for the long scrollable demos
/// (reference constraints, comprehensive form, etc.) to render their full
/// content without clipping, so the resulting PNG can be inspected in one piece
/// and a vertical overflow means a real layout fault rather than a demo simply
/// being longer than the window.
const Size viewport = Size(1280, 2400);

/// Pixel ratio for the mount. 1.0 keeps PNGs small and makes logical pixels and
/// image pixels the same number in every assertion.
const double pixelRatio = 1.0;

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
String? scopeIdFor(String slug) {
  final override = _scopeIdOverrides[slug];
  if (override != null) return override;
  final match = RegExp(r'^widget_(\d{2})_').firstMatch(slug);
  return match == null ? null : 'demo${match.group(1)}';
}

/// Install everything a demo needs from its host: resources, fonts, offline
/// images and the sensitive-content stub. Call from `setUpAll`.
///
/// [realFonts] chooses what text is measured against, and the two suites choose
/// differently on purpose:
///
/// - `true` — load Roboto and MaterialIcons out of the Flutter SDK cache. The
///   screenshot harness needs this: a page of Ahem's black boxes is not a
///   picture anybody can read.
/// - `false` (default) — keep the Ahem placeholder `flutter test` installs.
///   Every Ahem glyph is a full em square, so essentially all text is *wider*
///   than the same string in Roboto, and long text wraps to more lines and
///   therefore also grows taller. That makes Ahem a harsher viewport than the
///   app's, which is what the overflow gate wants: a layout that survives it
///   has real slack, not slack borrowed from one font's narrow glyphs. It is
///   also the only choice that is reproducible everywhere — Ahem ships inside
///   `flutter_test`, whereas the SDK fonts depend on `FLUTTER_ROOT` and a
///   downloaded artifact, so a real-font gate silently stops gating on any
///   machine that lacks them.
Future<void> installDemoEnvironment(
  TestWidgetsFlutterBinding binding, {
  bool realFonts = false,
}) async {
  // Match main.dart's bootstrap so TomText resources resolve correctly.
  initializeDemoResources();
  if (realFonts) await _loadSdkFonts();
  HttpOverrides.global = _OfflineHttpOverrides();
  // Why: SensitiveContent asks the platform whether content sensitivity is
  // supported and caches the answer; unregister asserts that the answer has
  // arrived. With no handler the query never completes, so tearing the demo
  // down at end of test trips that assert. Answering "not supported" is the
  // truthful reply for the desktop host this harness runs on.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.sensitiveContent,
    (call) async => call.method == 'SensitiveContent.isSupported' ? false : null,
  );
}

/// Undo [installDemoEnvironment]. Call from `tearDownAll`.
void restoreDemoEnvironment(TestWidgetsFlutterBinding binding) {
  HttpOverrides.global = null;
  binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.sensitiveContent, null);
}

/// A demo mounted at [viewport] and pumped to a steady frame.
class DemoMount {
  /// Boundary wrapping the demo, for callers that want to rasterise it.
  final GlobalKey captureKey;

  /// One entry per distinct "A RenderFlex overflowed by N pixels …" report
  /// raised while laying the demo out. Empty is the healthy case.
  final List<String> overflows;

  const DemoMount({required this.captureKey, required this.overflows});
}

/// Mount [slug]'s demo at [viewport] and pump until the frame is steady.
///
/// Overflow reports are captured rather than thrown: both callers want the
/// mount to complete either way — the screenshot harness so it can write the
/// PNG whose striped banner *is* the evidence, the gate so it can report every
/// overflow in one run instead of dying on the first.
Future<DemoMount> pumpDemo(WidgetTester tester, String slug) async {
  final factory = demos.firstWhere((d) => d.$1 == slug).$2;

  tester.view.physicalSize = viewport * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // The demo must be *constructed* inside its scope: TomNodeBase resolves its
  // resource base path in the constructor, not in build.
  final scopeId = scopeIdFor(slug);
  final demo = scopeId == null ? factory() : TomScope.withScope(scopeId, factory);

  final captureKey = GlobalKey(debugLabel: 'demo-$slug');
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
            size: viewport,
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
    // Fall back to a few plain pumps so we still reach a frame.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  return DemoMount(
    captureKey: captureKey,
    overflows: overflows.toSet().toList(),
  );
}

/// True for the "A RenderFlex overflowed by N pixels" layout report.
///
/// Singled out from other framework errors because it is the one finding this
/// harness is expected to produce rather than crash on: it is *visible* —
/// Flutter paints the striped banner — so letting it abort the mount would
/// suppress the very frame that shows it.
bool _isOverflowReport(FlutterErrorDetails details) =>
    details.library == 'rendering library' &&
    details.exception.toString().contains('overflowed by');

/// Replaces the test-only Ahem font with the real Roboto and Material Icons.
///
/// The fonts come out of the Flutter SDK cache, so no asset is added to this
/// package — and so this can fail on a machine that has not downloaded the
/// `material_fonts` artifact. It degrades rather than throws: the run continues
/// under Ahem and says so. That is survivable precisely because the only caller
/// is the screenshot harness, which asserts nothing; the gate never depends on
/// these fonts being present.
Future<void> _loadSdkFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final dir = root == null
      ? null
      : Directory('$root/bin/cache/artifacts/material_fonts');
  if (dir == null || !dir.existsSync()) {
    debugPrint('demo harness: SDK fonts not found; mounting with the Ahem '
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
        file
            .readAsBytes()
            .then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
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

/// Serves every image request a demo makes with a 1x1 transparent PNG.
///
/// Keeps the harness hermetic (no network in a test run) and stops a remote
/// asset from rendering as a broken-image placeholder.
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
