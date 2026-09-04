/// Example: platform detection through TomPlatformUtils
///
/// This example demonstrates [TomPlatformUtils], the indirection every Tom
/// library goes through instead of touching `dart:io` or `dart:html`:
/// - [TomPlatformUtils.setCurrentPlatform] installs the implementation, and
///   [TomPlatformUtils.current] is what the whole process then answers with
/// - [TomFallbackPlatformUtils] is what is installed until you install
///   something: it serves console output and isolate identity, and throws
///   [UnimplementedError] for every detection question
/// - the detection predicates partition the host — exactly one operating
///   system, exactly one environment type
/// - [TomPlatformUtils.envVars] carries configuration that must not come from
///   `Platform.environment`, because on the web there is no such thing
///
/// Every claim the example makes is also an `assert`, so a mistake fails the
/// run instead of scrolling past in the printed transcript.
///
/// `02_environment_platform_example.dart` and
/// `03_initialization_sequence_example.dart` install the real
/// `TomStandalonePlatformUtils`; this file works with local implementations so
/// it can show what each contract actually promises.
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// Example Support Classes
// =============================================================================
// In production, use TomStandalonePlatformUtils (server) or
// TomFlutterPlatformUtils (client).

/// A platform implementation that answers from `dart:io`.
///
/// This is the shape a real implementation has: every question is delegated to
/// whatever the host can actually answer.
class SamplePlatformUtils extends TomFallbackPlatformUtils {
  @override
  bool isWeb() => false; // We're in a Dart VM, not a browser.

  @override
  bool isDesktop() =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  bool isMobile() => Platform.isAndroid || Platform.isIOS;

  @override
  bool isMacOs() => Platform.isMacOS;

  @override
  bool isWindows() => Platform.isWindows;

  @override
  bool isLinux() => Platform.isLinux;

  @override
  bool isFuchsia() => Platform.isFuchsia;

  @override
  bool isAndroid() => Platform.isAndroid;

  @override
  bool isIos() => Platform.isIOS;

  @override
  http.Client httpClient() => http.Client();

  @override
  String getIsolateName() => 'main';

  @override
  String getBrowserLocation() => 'N/A (not in browser)';

  @override
  void out(String message) => stdout.writeln(message);

  @override
  void outError(String message) => stderr.writeln(message);
}

/// A platform implementation that reports an Android phone regardless of the
/// host it runs on.
///
/// Deliberately a lie: the samples run on a desktop VM, so if the process
/// starts answering "Android" after this is installed, the answers can only be
/// coming from the installed implementation rather than from the machine.
class StubAndroidPlatformUtils extends SamplePlatformUtils {
  @override
  bool isDesktop() => false;

  @override
  bool isMobile() => true;

  @override
  bool isAndroid() => true;

  @override
  bool isIos() => false;

  @override
  bool isMacOs() => false;

  @override
  bool isWindows() => false;

  @override
  bool isLinux() => false;

  @override
  bool isFuchsia() => false;

  @override
  String getIsolateName() => 'android-main';
}

/// A platform implementation that keeps console output instead of writing it.
///
/// [out] and [outError] have no return value, so the only way to observe that
/// a message went where it was addressed is to install an implementation that
/// can be asked afterwards.
class CapturingPlatformUtils extends SamplePlatformUtils {
  final List<String> written = [];
  final List<String> writtenToError = [];

  @override
  void out(String message) => written.add(message);

  @override
  void outError(String message) => writtenToError.add(message);
}

// =============================================================================
// Main Example Function
// =============================================================================

/// Runs the platform-detection demonstrations.
void run() {
  print('=== 01: Platform Detection Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: the fallback serves console output and refuses detection
  // ---------------------------------------------------------------------------
  // Until an application installs an implementation, this is what is answering.
  TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());
  final fallback = TomPlatformUtils.current;

  final fallbackBrowserLocation = fallback.getBrowserLocation();
  final fallbackIsolateName = fallback.getIsolateName();

  // Detection has no sensible default, so the fallback declines rather than
  // guessing — which is what turns "nobody called setCurrentPlatform" into a
  // loud failure instead of a quietly wrong branch.
  var fallbackRefusedDetection = false;
  try {
    fallback.isDesktop();
  } on UnimplementedError {
    fallbackRefusedDetection = true;
  }

  assert(
    fallbackBrowserLocation == '',
    'The fallback answers the browser location with an empty string',
  );
  assert(
    fallbackIsolateName == '',
    'The fallback answers the isolate name with an empty string',
  );
  assert(
    fallbackRefusedDetection,
    'The fallback must refuse a detection question, not answer it',
  );

  print('1. The fallback serves output and declines to detect anything:');
  print('   getBrowserLocation() : "$fallbackBrowserLocation" (empty)');
  print('   getIsolateName()     : "$fallbackIsolateName" (empty)');
  print('   isDesktop() threw UnimplementedError: $fallbackRefusedDetection');
  print('');

  // ---------------------------------------------------------------------------
  // Example 2: current is the implementation that was installed
  // ---------------------------------------------------------------------------
  final stub = StubAndroidPlatformUtils();
  TomPlatformUtils.setCurrentPlatform(stub);

  // Asked on a desktop VM, and answered "Android" — so the answer came from
  // the installed implementation, which is the entire point of the
  // indirection.
  final stubSaysMobile = TomPlatformUtils.current.isMobile();
  final stubSaysAndroid = TomPlatformUtils.current.isAndroid();
  final stubSaysDesktop = TomPlatformUtils.current.isDesktop();
  final stubIsolateName = TomPlatformUtils.current.getIsolateName();

  assert(
    identical(TomPlatformUtils.current, stub),
    'current returns the instance that was installed',
  );
  assert(stubSaysMobile, 'The installed implementation decides isMobile()');
  assert(stubSaysAndroid, 'The installed implementation decides isAndroid()');
  assert(
    !stubSaysDesktop,
    'The host is a desktop, so a desktop answer here would mean the '
    'indirection was bypassed',
  );
  assert(
    stubIsolateName == 'android-main',
    'Isolate identity comes from the implementation too',
  );

  print('2. The answers come from the installed implementation, not the host:');
  print('   isMobile()       : $stubSaysMobile');
  print('   isAndroid()      : $stubSaysAndroid');
  print(
    '   isDesktop()      : $stubSaysDesktop (the host really is a desktop)',
  );
  print('   getIsolateName() : $stubIsolateName');
  print('');

  // ---------------------------------------------------------------------------
  // Example 3: the predicates partition the host
  // ---------------------------------------------------------------------------
  final sample = SamplePlatformUtils();
  TomPlatformUtils.setCurrentPlatform(sample);
  final platform = TomPlatformUtils.current;

  final operatingSystems = <String, bool>{
    'macos': platform.isMacOs(),
    'windows': platform.isWindows(),
    'linux': platform.isLinux(),
    'fuchsia': platform.isFuchsia(),
    'android': platform.isAndroid(),
    'ios': platform.isIos(),
  };
  final detectedOs = operatingSystems.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList();

  final environments = [
    platform.isDesktop(),
    platform.isMobile(),
    platform.isWeb(),
  ];
  final environmentCount = environments.where((flag) => flag).length;

  // A host is one operating system, so two `true`s would mean a branch
  // somewhere runs twice and a caller that takes the first match runs the
  // wrong one.
  assert(
    detectedOs.length == 1,
    'Exactly one operating system must report true, got $detectedOs',
  );
  assert(
    detectedOs.single == Platform.operatingSystem,
    'The detected OS must be the one the VM reports: '
    '${detectedOs.single} vs ${Platform.operatingSystem}',
  );
  assert(
    environmentCount == 1,
    'Exactly one environment type must report true, got $environmentCount',
  );
  assert(!platform.isWeb(), 'A Dart VM run is not a browser run');

  print('3. The predicates partition the host — one OS, one environment:');
  print('   operating-system flags   : $operatingSystems');
  print('   reporting true           : $detectedOs');
  print('   [desktop, mobile, web]   : $environments');
  print('   environment flags true   : $environmentCount');
  print('');

  // ---------------------------------------------------------------------------
  // Example 4: environment variables
  // ---------------------------------------------------------------------------
  // Held by TomPlatformUtils rather than read from Platform.environment,
  // because a web build has no process environment to read.
  TomPlatformUtils.envVars['testKey'] = 'testValue';

  final readThroughPlatform = platform.getTomEnvVars()['testKey'];

  TomPlatformUtils.envVars.remove('testKey');
  final readAfterRemoval = platform.getTomEnvVars()['testKey'];

  assert(
    readThroughPlatform == 'testValue',
    'getTomEnvVars() reads the map the application populated',
  );
  assert(
    readAfterRemoval == null,
    'getTomEnvVars() is a view of that map, not a copy taken at startup',
  );

  print('4. Environment variables are held by TomPlatformUtils itself:');
  print('   getTomEnvVars()["testKey"] after setting  : $readThroughPlatform');
  print('   getTomEnvVars()["testKey"] after removing : $readAfterRemoval');
  print('');

  // ---------------------------------------------------------------------------
  // Example 5: console output goes where it is addressed
  // ---------------------------------------------------------------------------
  final capturing = CapturingPlatformUtils();
  TomPlatformUtils.setCurrentPlatform(capturing);

  TomPlatformUtils.current.out('normal message');
  TomPlatformUtils.current.outError('error message');

  assert(
    capturing.written.single == 'normal message',
    'out() reaches the implementation, exactly once, unaltered',
  );
  assert(
    capturing.writtenToError.single == 'error message',
    'outError() is a separate channel, not a relabelled out()',
  );

  print('5. Console output reaches the channel it was addressed to:');
  print('   out() was handed      : ${capturing.written}');
  print('   outError() was handed : ${capturing.writtenToError}');
  print('');

  // ---------------------------------------------------------------------------
  // Example 6: the HTTP client factory
  // ---------------------------------------------------------------------------
  TomPlatformUtils.setCurrentPlatform(sample);

  final firstClient = TomPlatformUtils.current.httpClient();
  final secondClient = TomPlatformUtils.current.httpClient();

  // Each caller owns — and must close — the client it was handed. A shared
  // one would be closed out from under whoever was still using it.
  final clientsAreDistinct = !identical(firstClient, secondClient);

  firstClient.close();
  secondClient.close();

  assert(
    clientsAreDistinct,
    'httpClient() must hand back a fresh client per call',
  );

  // The fallback cannot make one: there is no platform-neutral HTTP client.
  var fallbackRefusedClient = false;
  try {
    TomFallbackPlatformUtils().httpClient();
  } on UnimplementedError {
    fallbackRefusedClient = true;
  }
  assert(
    fallbackRefusedClient,
    'The fallback declines to invent an HTTP client',
  );

  print('6. Every call to the HTTP client factory owns its own client:');
  print('   two calls handed back distinct clients : $clientsAreDistinct');
  print('   the fallback refuses to invent one     : $fallbackRefusedClient');
  print('');

  // Leave a working implementation installed for whatever runs next.
  TomPlatformUtils.setCurrentPlatform(sample);
}

/// Standalone entry point.
void main() {
  requireAsserts();
  run();
}
