/// Demonstrates platform detection and utilities using TomPlatformUtils.
///
/// This example covers:
/// - Understanding the TomPlatformUtils singleton pattern
/// - Using TomFallbackPlatformUtils default implementation
/// - Creating custom platform implementations
/// - Console output through platform utilities
/// - Environment variables with envVars
/// - Browser location and isolate name utilities
///
/// The platform utilities provide an abstraction layer for platform-specific
/// operations, enabling cross-platform code to run in web, mobile, and desktop
/// environments without direct platform dependencies.
library;

import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Custom Platform Implementation for Examples
// =============================================================================

/// A mock platform implementation that simulates a macOS desktop environment.
///
/// This demonstrates how to create a custom [TomPlatformUtils] implementation
/// for a specific platform (in this case, macOS desktop).
class MockMacOsPlatformUtils extends TomPlatformUtils {
  @override
  bool isDesktop() => true;

  @override
  bool isMobile() => false;

  @override
  bool isWeb() => false;

  @override
  bool isWindows() => false;

  @override
  bool isLinux() => false;

  @override
  bool isMacOs() => true;

  @override
  bool isFuchsia() => false;

  @override
  bool isAndroid() => false;

  @override
  bool isIos() => false;

  @override
  void out(String s) => print('[OUT] $s');

  @override
  void outError(String s) => print('[ERROR] $s');

  @override
  Client httpClient() => Client();

  @override
  String? getBrowserLocation() => null;

  @override
  String getIsolateName() => 'main';

  @override
  String toString() => 'MockMacOsPlatformUtils';
}

/// A mock platform implementation that simulates a web browser environment.
class MockWebPlatformUtils extends TomPlatformUtils {
  final String _browserLocation;

  MockWebPlatformUtils({String browserLocation = 'https://example.com/app'})
      : _browserLocation = browserLocation;

  @override
  bool isDesktop() => false;

  @override
  bool isMobile() => false;

  @override
  bool isWeb() => true;

  @override
  bool isWindows() => false;

  @override
  bool isLinux() => false;

  @override
  bool isMacOs() => false;

  @override
  bool isFuchsia() => false;

  @override
  bool isAndroid() => false;

  @override
  bool isIos() => false;

  @override
  void out(String s) => print('[WEB] $s');

  @override
  void outError(String s) => print('[WEB-ERROR] $s');

  @override
  Client httpClient() => Client();

  @override
  String? getBrowserLocation() => _browserLocation;

  @override
  String getIsolateName() => 'web-main';

  @override
  String toString() => 'MockWebPlatformUtils';
}

/// A mock platform implementation that simulates an Android mobile environment.
class MockAndroidPlatformUtils extends TomPlatformUtils {
  @override
  bool isDesktop() => false;

  @override
  bool isMobile() => true;

  @override
  bool isWeb() => false;

  @override
  bool isWindows() => false;

  @override
  bool isLinux() => false;

  @override
  bool isMacOs() => false;

  @override
  bool isFuchsia() => false;

  @override
  bool isAndroid() => true;

  @override
  bool isIos() => false;

  @override
  void out(String s) => print('[ANDROID] $s');

  @override
  void outError(String s) => print('[ANDROID-ERROR] $s');

  @override
  Client httpClient() => Client();

  @override
  String? getBrowserLocation() => null;

  @override
  String getIsolateName() => 'android-main';

  @override
  String toString() => 'MockAndroidPlatformUtils';
}

void run() {
  print('=== 01: Platform Detection Example ===\n');

  // Store original platform to restore later
  final originalPlatform = TomPlatformUtils.current;

  // ===========================================================================
  // Example 1: TomFallbackPlatformUtils Behavior
  // ===========================================================================

  print('1. Understanding TomFallbackPlatformUtils (default implementation):');

  // Reset to fallback for demonstration
  TomPlatformUtils.setCurrentPlatform(TomFallbackPlatformUtils());

  final fallbackPlatform = TomPlatformUtils.current;
  final fallbackType = fallbackPlatform.runtimeType.toString();

  print('   - Default platform type: $fallbackType');

  // Fallback's working methods
  final fallbackBrowserLocation = fallbackPlatform.getBrowserLocation();
  final fallbackIsolateName = fallbackPlatform.getIsolateName();

  print('   - getBrowserLocation(): "$fallbackBrowserLocation" (empty string)');
  print('   - getIsolateName(): "$fallbackIsolateName" (empty string)');

  // Test out() method - it works!
  fallbackPlatform.out('   - out() method works with fallback!');

  // Demonstrate that platform detection throws with fallback
  var fallbackThrows = false;
  try {
    fallbackPlatform.isDesktop();
  } catch (e) {
    fallbackThrows = true;
    print('   - isDesktop() throws UnimplementedError (expected)');
  }

  print('');

  // ===========================================================================
  // Example 2: Setting a Custom Platform Implementation
  // ===========================================================================

  print('2. Setting a custom platform implementation:');

  // Set macOS platform
  final macOsPlatform = MockMacOsPlatformUtils();
  TomPlatformUtils.setCurrentPlatform(macOsPlatform);

  final currentPlatformAfterSet = TomPlatformUtils.current;
  final currentPlatformType = currentPlatformAfterSet.runtimeType.toString();

  print('   - Set platform to: MockMacOsPlatformUtils');
  print('   - TomPlatformUtils.current is now: $currentPlatformType');

  // Verify it's the same instance
  final isSameInstance = identical(TomPlatformUtils.current, macOsPlatform);
  print('   - Same instance as set: $isSameInstance');

  print('');

  // ===========================================================================
  // Example 3: Platform Detection Methods - Desktop
  // ===========================================================================

  print('3. Platform detection for macOS desktop:');

  TomPlatformUtils.setCurrentPlatform(MockMacOsPlatformUtils());
  final desktopPlatform = TomPlatformUtils.current;

  // Environment type detection
  final macIsDesktop = desktopPlatform.isDesktop();
  final macIsMobile = desktopPlatform.isMobile();
  final macIsWeb = desktopPlatform.isWeb();

  print('   Environment type:');
  print('   - isDesktop(): $macIsDesktop');
  print('   - isMobile(): $macIsMobile');
  print('   - isWeb(): $macIsWeb');

  // Desktop OS detection
  final macIsWindows = desktopPlatform.isWindows();
  final macIsLinux = desktopPlatform.isLinux();
  final macIsMacOs = desktopPlatform.isMacOs();
  final macIsFuchsia = desktopPlatform.isFuchsia();

  print('   Desktop OS:');
  print('   - isWindows(): $macIsWindows');
  print('   - isLinux(): $macIsLinux');
  print('   - isMacOs(): $macIsMacOs');
  print('   - isFuchsia(): $macIsFuchsia');

  // Mobile OS detection (should be false on desktop)
  final macIsAndroid = desktopPlatform.isAndroid();
  final macIsIos = desktopPlatform.isIos();

  print('   Mobile OS (should be false):');
  print('   - isAndroid(): $macIsAndroid');
  print('   - isIos(): $macIsIos');

  print('');

  // ===========================================================================
  // Example 4: Platform Detection Methods - Mobile
  // ===========================================================================

  print('4. Platform detection for Android mobile:');

  TomPlatformUtils.setCurrentPlatform(MockAndroidPlatformUtils());
  final mobilePlatform = TomPlatformUtils.current;

  // Environment type detection
  final androidIsDesktop = mobilePlatform.isDesktop();
  final androidIsMobile = mobilePlatform.isMobile();
  final androidIsWeb = mobilePlatform.isWeb();

  print('   Environment type:');
  print('   - isDesktop(): $androidIsDesktop');
  print('   - isMobile(): $androidIsMobile');
  print('   - isWeb(): $androidIsWeb');

  // Mobile OS detection
  final androidIsAndroid = mobilePlatform.isAndroid();
  final androidIsIos = mobilePlatform.isIos();

  print('   Mobile OS:');
  print('   - isAndroid(): $androidIsAndroid');
  print('   - isIos(): $androidIsIos');

  print('');

  // ===========================================================================
  // Example 5: Platform Detection Methods - Web
  // ===========================================================================

  print('5. Platform detection for web browser:');

  final webPlatform = MockWebPlatformUtils(
    browserLocation: 'https://myapp.example.com/dashboard',
  );
  TomPlatformUtils.setCurrentPlatform(webPlatform);
  final webCurrent = TomPlatformUtils.current;

  // Environment type detection
  final webIsDesktop = webCurrent.isDesktop();
  final webIsMobile = webCurrent.isMobile();
  final webIsWeb = webCurrent.isWeb();

  print('   Environment type:');
  print('   - isDesktop(): $webIsDesktop');
  print('   - isMobile(): $webIsMobile');
  print('   - isWeb(): $webIsWeb');

  // Web-specific features
  final webBrowserLocation = webCurrent.getBrowserLocation();
  final webIsolateName = webCurrent.getIsolateName();

  print('   Web-specific:');
  print('   - getBrowserLocation(): $webBrowserLocation');
  print('   - getIsolateName(): $webIsolateName');

  print('');

  // ===========================================================================
  // Example 6: Console Output Methods
  // ===========================================================================

  print('6. Console output through platform utilities:');

  TomPlatformUtils.setCurrentPlatform(MockMacOsPlatformUtils());

  print('   Using out() for normal messages:');
  TomPlatformUtils.current.out('   This is a normal output message');

  print('   Using outError() for error messages:');
  TomPlatformUtils.current.outError('   This is an error output message');

  print('');

  // ===========================================================================
  // Example 7: Environment Variables
  // ===========================================================================

  print('7. Working with environment variables:');

  // Clear any existing env vars
  TomPlatformUtils.envVars.clear();

  // Set environment variables
  TomPlatformUtils.envVars['API_BASE_URL'] = 'https://api.example.com';
  TomPlatformUtils.envVars['DEBUG_MODE'] = 'true';
  TomPlatformUtils.envVars['MAX_CONNECTIONS'] = '10';

  final envVarsCount = TomPlatformUtils.envVars.length;
  print('   - Set $envVarsCount environment variables');

  // Retrieve through getTomEnvVars()
  final retrievedEnvVars = TomPlatformUtils.current.getTomEnvVars();
  final apiBaseUrl = retrievedEnvVars['API_BASE_URL'];
  final debugMode = retrievedEnvVars['DEBUG_MODE'];
  final maxConnections = retrievedEnvVars['MAX_CONNECTIONS'];

  print('   - API_BASE_URL: $apiBaseUrl');
  print('   - DEBUG_MODE: $debugMode');
  print('   - MAX_CONNECTIONS: $maxConnections');

  // Check for non-existent key
  final nonExistent = retrievedEnvVars['NON_EXISTENT'];
  print('   - NON_EXISTENT: $nonExistent (null)');

  print('');

  // ===========================================================================
  // Example 8: HTTP Client Creation
  // ===========================================================================

  print('8. Creating HTTP clients:');

  TomPlatformUtils.setCurrentPlatform(MockMacOsPlatformUtils());

  final httpClient = TomPlatformUtils.current.httpClient();
  final httpClientType = httpClient.runtimeType.toString();

  print('   - Created HTTP client of type: $httpClientType');
  print('   - Client is ready for HTTP requests');

  // Clean up the client
  httpClient.close();
  print('   - Client closed after use');

  print('');

  // ===========================================================================
  // Example 9: Conditional Logic Based on Platform
  // ===========================================================================

  print('9. Conditional logic based on platform:');

  // Demonstrate platform-specific logic pattern
  String getPlatformMessage(TomPlatformUtils platform) {
    if (platform.isWeb()) {
      return 'Running in browser at ${platform.getBrowserLocation()}';
    } else if (platform.isMobile()) {
      if (platform.isAndroid()) {
        return 'Running on Android device';
      } else if (platform.isIos()) {
        return 'Running on iOS device';
      }
      return 'Running on unknown mobile platform';
    } else if (platform.isDesktop()) {
      if (platform.isMacOs()) {
        return 'Running on macOS';
      } else if (platform.isWindows()) {
        return 'Running on Windows';
      } else if (platform.isLinux()) {
        return 'Running on Linux';
      }
      return 'Running on unknown desktop platform';
    }
    return 'Unknown platform';
  }

  // Test with different platforms
  TomPlatformUtils.setCurrentPlatform(MockMacOsPlatformUtils());
  final macMessage = getPlatformMessage(TomPlatformUtils.current);
  print('   - macOS: $macMessage');

  TomPlatformUtils.setCurrentPlatform(MockAndroidPlatformUtils());
  final androidMessage = getPlatformMessage(TomPlatformUtils.current);
  print('   - Android: $androidMessage');

  TomPlatformUtils.setCurrentPlatform(
    MockWebPlatformUtils(browserLocation: 'https://app.example.com'),
  );
  final webMessage = getPlatformMessage(TomPlatformUtils.current);
  print('   - Web: $webMessage');

  print('');

  // Clean up: restore original platform and clear env vars
  TomPlatformUtils.setCurrentPlatform(originalPlatform);
  TomPlatformUtils.envVars.clear();

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: TomFallbackPlatformUtils behavior
  assert(fallbackType == 'TomFallbackPlatformUtils');
  assert(fallbackBrowserLocation == '');
  assert(fallbackIsolateName == '');
  assert(fallbackThrows == true); // Platform detection throws with fallback

  // Example 2: Setting custom platform implementation
  assert(currentPlatformType == 'MockMacOsPlatformUtils');
  assert(isSameInstance == true);

  // Example 3: Platform detection - Desktop (macOS)
  assert(macIsDesktop == true);
  assert(macIsMobile == false);
  assert(macIsWeb == false);
  assert(macIsWindows == false);
  assert(macIsLinux == false);
  assert(macIsMacOs == true);
  assert(macIsFuchsia == false);
  assert(macIsAndroid == false);
  assert(macIsIos == false);

  // Example 4: Platform detection - Mobile (Android)
  assert(androidIsDesktop == false);
  assert(androidIsMobile == true);
  assert(androidIsWeb == false);
  assert(androidIsAndroid == true);
  assert(androidIsIos == false);

  // Example 5: Platform detection - Web
  assert(webIsDesktop == false);
  assert(webIsMobile == false);
  assert(webIsWeb == true);
  assert(webBrowserLocation == 'https://myapp.example.com/dashboard');
  assert(webIsolateName == 'web-main');

  // Example 7: Environment variables
  assert(envVarsCount == 3);
  assert(apiBaseUrl == 'https://api.example.com');
  assert(debugMode == 'true');
  assert(maxConnections == '10');
  assert(nonExistent == null);

  // Example 8: HTTP client creation
  assert(httpClientType == 'IOClient');

  // Example 9: Conditional platform logic
  assert(macMessage == 'Running on macOS');
  assert(androidMessage == 'Running on Android device');
  assert(webMessage == 'Running in browser at https://app.example.com');
}
