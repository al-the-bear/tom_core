import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// What every Flutter variant answers the same way.
///
/// The three compile-time variants of `TomFlutterPlatformUtils` — native,
/// web and neutral — differ in how they reach the network, name their isolate
/// and identify themselves. They do **not** differ in what platform the build
/// is targeting, because all three read the same two Flutter symbols to decide
/// it: [defaultTargetPlatform] and [kIsWeb]. Those nine answers live here, once,
/// together with [getBrowserLocation], which two of the three answered
/// identically for the same reason — there is no browser location unless there
/// is a browser, and only one variant is one.
///
/// ## Why a fourth file rather than a member of one variant
///
/// The conditional import in `platform_detection_client.dart` resolves to
/// whichever variant the target has, so all three must declare a class of the
/// *same* name. A shared base therefore cannot be one of them; it has to be a
/// differently-named class in a file all three import unconditionally, which is
/// this one. It has no conditional import of its own and touches no
/// target-specific library, so it compiles on every target.
///
/// ## Deliberately concrete
///
/// It could be `abstract` — nothing constructs it in `lib/`. It is not, and
/// that is the point of extracting it at all. A conditional import means no
/// single host can compile more than one variant, so the nine predicates were
/// exercised only through whichever variant the test host happened to select
/// and the other two copies were untested *by construction*. Sharing one copy
/// does not merely remove lines: it puts the logic somewhere a test can reach
/// without a target, and this class being instantiable is what makes that true.
///
/// What it does not answer it inherits. [TomFallbackPlatformUtils] throws
/// `UnimplementedError` from [httpClient], which is the honest answer here —
/// which client to build is precisely what the variants exist to decide.
///
/// ## What the predicates mean
///
/// "The **build's** target", not "the machine this process is running on".
/// [defaultTargetPlatform] is Flutter's answer to the former, and under
/// `flutter test` it is `android` whatever the host is. A caller that reads
/// [isMobile] expecting to learn about the hardware gets a true answer to a
/// different question.
///
/// There is no target for which `isDesktop() || isMobile()` holds by
/// construction: Fuchsia belongs to neither family.
class TomFlutterPlatformUtilsBase extends TomFallbackPlatformUtils {
  /// Allows the variants' own `const`-free constructors to be trivial.
  TomFlutterPlatformUtilsBase();

  @override
  bool isDesktop() =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool isMobile() =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // The one predicate that does not read `defaultTargetPlatform`: whether this
  // is a *web build* is a compile-time fact about the toolchain rather than a
  // target in the enumeration, and `kIsWeb` is where Flutter states it.
  @override
  bool isWeb() => kIsWeb;

  @override
  bool isFuchsia() => defaultTargetPlatform == TargetPlatform.fuchsia;
  @override
  bool isWindows() => defaultTargetPlatform == TargetPlatform.windows;
  @override
  bool isLinux() => defaultTargetPlatform == TargetPlatform.linux;
  @override
  bool isMacOs() => defaultTargetPlatform == TargetPlatform.macOS;
  @override
  bool isAndroid() => defaultTargetPlatform == TargetPlatform.android;
  @override
  bool isIos() => defaultTargetPlatform == TargetPlatform.iOS;

  // `null`, where [TomFallbackPlatformUtils] answers `""`. There is no browser
  // location on a target that is not a browser, and an empty string is a
  // location that happens to be blank — a caller testing for one would take
  // the wrong branch. The web variant is the only one that has an answer, and
  // overrides.
  @override
  String? getBrowserLocation() => null;
}
