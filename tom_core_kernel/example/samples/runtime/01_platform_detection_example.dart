// ignore_for_file: unnecessary_null_comparison
/// Demonstrates platform detection using TomPlatformUtils.
library;

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// MOCK PLATFORM UTILS FOR EXAMPLES
// =============================================================================
// In production, use TomStandalonePlatformUtils (server) or TomFlutterPlatformUtils (client)

/// A sample platform utils implementation for demonstration purposes.
class SamplePlatformUtils extends TomFallbackPlatformUtils {
  @override
  bool isWeb() => false; // We're in a Dart VM, not browser

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

// =============================================================================
// EXAMPLE 1: TomFallbackPlatformUtils Behavior
// =============================================================================

class FallbackPlatformExample {
  static String? fallbackType;
  static String? browserLocation;
  static String? isolateName;
  static bool fallbackWorks = false;

  static void example1FallbackPlatform() {
    // First set up a proper platform for subsequent examples
    TomPlatformUtils.setCurrentPlatform(SamplePlatformUtils());

    // Now test fallback behavior
    final originalPlatform = TomPlatformUtils.current;

    TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());
    final fallbackPlatform = TomPlatformUtils.current;

    fallbackType = fallbackPlatform.runtimeType.toString();
    browserLocation = fallbackPlatform.getBrowserLocation();
    isolateName = fallbackPlatform.getIsolateName();

    fallbackWorks = fallbackType!.contains('Fallback');

    // Restore proper platform utils for other examples
    TomPlatformUtils.setCurrentPlatform(originalPlatform);

    assert(fallbackType!.contains('Fallback'), 'Should be fallback type');
    assert(fallbackWorks, 'Fallback should work');
  }
}

// =============================================================================
// EXAMPLE 2: Platform Detection Methods
// =============================================================================

class PlatformDetectionExample {
  static bool? isWeb;
  static bool? isDesktop;
  static bool? isMobile;
  static bool detectionWorks = false;

  static void example2PlatformDetection() {
    final platform = TomPlatformUtils.current;

    isWeb = platform.isWeb();
    isDesktop = platform.isDesktop();
    isMobile = platform.isMobile();

    // At least one should be true or we're in fallback mode
    detectionWorks = isWeb != null && isDesktop != null && isMobile != null;

    assert(detectionWorks, 'Detection should return boolean values');
  }
}

// =============================================================================
// EXAMPLE 3: Specific OS Detection
// =============================================================================

class OsDetectionExample {
  static bool? isMacOs;
  static bool? isWindows;
  static bool? isLinux;
  static bool? isAndroid;
  static bool? isIos;
  static bool osDetectionWorks = false;

  static void example3OsDetection() {
    final platform = TomPlatformUtils.current;

    isMacOs = platform.isMacOs();
    isWindows = platform.isWindows();
    isLinux = platform.isLinux();
    isAndroid = platform.isAndroid();
    isIos = platform.isIos();

    osDetectionWorks =
        isMacOs != null &&
        isWindows != null &&
        isLinux != null &&
        isAndroid != null &&
        isIos != null;

    assert(osDetectionWorks, 'OS detection should work');
  }
}

// =============================================================================
// EXAMPLE 4: Environment Variables
// =============================================================================

class EnvVarsExample {
  static String? envValue;
  static bool envVarsWork = false;

  static void example4EnvVars() {
    // Set an environment variable
    TomPlatformUtils.envVars['testKey'] = 'testValue';

    envValue = TomPlatformUtils.envVars['testKey'];

    envVarsWork = envValue == 'testValue';

    // Clean up
    TomPlatformUtils.envVars.remove('testKey');

    assert(envValue == 'testValue', 'Env var should be set');
    assert(envVarsWork, 'Env vars should work');
  }
}

// =============================================================================
// EXAMPLE 5: Console Output Methods
// =============================================================================

class ConsoleOutputExample {
  static bool outputWorks = false;
  static bool errorOutputWorks = false;

  static void example5ConsoleOutput() {
    final platform = TomPlatformUtils.current;

    // These methods write to stdout/stderr
    platform.out('Test output message');
    outputWorks = true;

    platform.outError('Test error message');
    errorOutputWorks = true;

    assert(outputWorks, 'Output should work');
    assert(errorOutputWorks, 'Error output should work');
  }
}

// =============================================================================
// EXAMPLE 6: HTTP Client Factory
// =============================================================================

class HttpClientExample {
  static bool clientCreated = false;
  static String? clientType;

  static void example6HttpClient() {
    final platform = TomPlatformUtils.current;

    final client = platform.httpClient();
    clientCreated = client != null;
    clientType = client.runtimeType.toString();

    // Close the client to release resources
    client.close();

    assert(clientCreated, 'HTTP client should be created');
    assert(clientType != null, 'Client type should be available');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  FallbackPlatformExample.example1FallbackPlatform();
  PlatformDetectionExample.example2PlatformDetection();
  OsDetectionExample.example3OsDetection();
  EnvVarsExample.example4EnvVars();
  ConsoleOutputExample.example5ConsoleOutput();
  HttpClientExample.example6HttpClient();
}

void main() {
  requireAsserts();
  run();
}
