/// Advanced Logging Configuration Example
///
/// This example demonstrates advanced logging features:
/// - Log level stack with push/pop
/// - Per-name log level configuration
/// - Log level exceptions pattern
/// - TomLoggable interface for custom log representation
/// - Global settings configuration
/// - limited() helper function
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Custom Loggable Classes
// ============================================================================

/// Example class implementing TomLoggable for custom log representation.
class UserAccount implements TomLoggable {
  final int id;
  final String username;
  final String email;
  final String sensitiveData;

  UserAccount({
    required this.id,
    required this.username,
    required this.email,
    this.sensitiveData = 'secret',
  });

  @override
  String get logRepresentation => 'User($id: $username)';

  @override
  String toString() => 'UserAccount{id: $id, username: $username, email: $email, sensitiveData: $sensitiveData}';
}

/// Another loggable class showing custom formatting.
class ApiRequest implements TomLoggable {
  final String method;
  final String path;
  final int? statusCode;
  final Duration? duration;

  ApiRequest({
    required this.method,
    required this.path,
    this.statusCode,
    this.duration,
  });

  @override
  String get logRepresentation {
    final status = statusCode != null ? ' -> $statusCode' : '';
    final time = duration != null ? ' (${duration!.inMilliseconds}ms)' : '';
    return '[$method] $path$status$time';
  }
}

// ============================================================================
// Example Class
// ============================================================================

class AdvancedLoggingExample {
  // Captured results
  static late TomLogLevel originalLevel;
  static late TomLogLevel pushedLevel;
  static late TomLogLevel poppedLevel;
  static bool levelStackWorks = false;
  static bool nameLevelWorks = false;
  static bool loggableWorks = false;
  static late String limitedResult;

  // --------------------------------------------------------------------------
  // Example 1: Log level stack (push/pop)
  // --------------------------------------------------------------------------
  static void example1LogLevelStack() {
    print('1. Log level stack with push/pop:');

    // Save original level
    originalLevel = tomLog.logLevel;
    print('   - Original level: ${originalLevel.levelPattern}');

    // Push a new level - temporarily increase verbosity
    tomLog.pushLogLevel(TomLogLevel.trace);
    pushedLevel = tomLog.logLevel;
    print('   - After push (trace): ${pushedLevel.levelPattern}');

    // This would log at trace level
    tomLog.trace('Detailed trace message (visible now)');

    // Pop to restore previous level
    tomLog.popLogLevel();
    poppedLevel = tomLog.logLevel;
    print('   - After pop: ${poppedLevel.levelPattern}');

    levelStackWorks = pushedLevel != originalLevel && poppedLevel.levelPattern == originalLevel.levelPattern;

    // Assertions
    assert(pushedLevel == TomLogLevel.trace, 'Should be trace after push');
  }

  // --------------------------------------------------------------------------
  // Example 2: Per-name log level configuration
  // --------------------------------------------------------------------------
  static void example2NameLevels() {
    print('\n2. Per-name log level configuration:');

    // Add custom levels for specific classes/methods
    tomLog.addNameLevel('DatabaseService', TomLogLevel.trace);
    tomLog.addNameLevel('ApiClient', TomLogLevel.debug);
    tomLog.addNameLevel('CacheManager.cleanup', TomLogLevel.warn);

    // Check configured levels
    final dbLevel = tomLog.getNameLevel('DatabaseService');
    final apiLevel = tomLog.getNameLevel('ApiClient');
    final cacheLevel = tomLog.getNameLevel('CacheManager.cleanup');
    final unknownLevel = tomLog.getNameLevel('UnknownClass');

    print('   - DatabaseService level: ${dbLevel?.levelPattern}');
    print('   - ApiClient level: ${apiLevel?.levelPattern}');
    print('   - CacheManager.cleanup level: ${cacheLevel?.levelPattern}');
    print('   - UnknownClass level: $unknownLevel');

    nameLevelWorks =
        dbLevel == TomLogLevel.trace &&
        apiLevel == TomLogLevel.debug &&
        unknownLevel == null;

    // Remove a name level
    tomLog.removeNameLevel('CacheManager.cleanup');
    final removedLevel = tomLog.getNameLevel('CacheManager.cleanup');
    print('   - After removal: $removedLevel');

    // Clean up
    tomLog.removeNameLevel('DatabaseService');
    tomLog.removeNameLevel('ApiClient');

    // Assertions
    assert(nameLevelWorks, 'Name levels should work');
    assert(removedLevel == null, 'Removed level should be null');
  }

  // --------------------------------------------------------------------------
  // Example 3: Log level exceptions pattern
  // --------------------------------------------------------------------------
  static void example3LogLevelExceptions() {
    print('\n3. Log level exceptions pattern:');

    // Set multiple name levels using a pattern string
    tomLog.setLogLevelExceptions('AuthService=TRACE,PaymentService=DEBUG,ReportGenerator=INFO');

    // Verify they were set
    final authLevel = tomLog.getNameLevel('AuthService');
    final paymentLevel = tomLog.getNameLevel('PaymentService');
    final reportLevel = tomLog.getNameLevel('ReportGenerator');

    print('   - Pattern: AuthService=TRACE,PaymentService=DEBUG,ReportGenerator=INFO');
    print('   - AuthService: ${authLevel?.levelPattern} (trace=${TomLogLevel.trace.levelPattern})');
    print('   - PaymentService: ${paymentLevel?.levelPattern} (debug=${TomLogLevel.debug.levelPattern})');
    print('   - ReportGenerator: ${reportLevel?.levelPattern} (info=${TomLogLevel.info.levelPattern})');

    // Clean up
    tomLog.removeNameLevel('AuthService');
    tomLog.removeNameLevel('PaymentService');
    tomLog.removeNameLevel('ReportGenerator');

    // Assertions
    assert(authLevel == TomLogLevel.trace, 'Auth should be trace');
    assert(paymentLevel == TomLogLevel.debug, 'Payment should be debug');
    assert(reportLevel == TomLogLevel.info, 'Report should be info');
  }

  // --------------------------------------------------------------------------
  // Example 4: Setting log level by name
  // --------------------------------------------------------------------------
  static void example4SetLevelByName() {
    print('\n4. Setting log level by name:');

    // Save current level
    final currentLevel = tomLog.logLevel;

    // Set by name using string
    tomLog.setLogLevelByName('DEVELOPMENT');
    print('   - Set to DEVELOPMENT: ${tomLog.logLevel.levelPattern}');

    tomLog.setLogLevelByName('PRODUCTION');
    print('   - Set to PRODUCTION: ${tomLog.logLevel.levelPattern}');

    tomLog.setLogLevelByName('SILENT');
    print('   - Set to SILENT: ${tomLog.logLevel.levelPattern}');

    // Available level names
    print('   - Available names: TRACE, DEBUG, TRAFFIC, INFO, WARN, STATUS,');
    print('     ERROR, SEVERE, FATAL, ALL, DEVELOPMENT, EXTENDED, ERRORS,');
    print('     PRODUCTION, STILL, SILENT, OFF');

    // Restore original level
    tomLog.setLogLevel(currentLevel);
  }

  // --------------------------------------------------------------------------
  // Example 5: TomLoggable interface
  // --------------------------------------------------------------------------
  static void example5TomLoggable() {
    print('\n5. TomLoggable interface for custom log representation:');

    final user = UserAccount(
      id: 123,
      username: 'john.doe',
      email: 'john@example.com',
      sensitiveData: 'password123',
    );

    final request = ApiRequest(
      method: 'POST',
      path: '/api/users',
      statusCode: 201,
      duration: Duration(milliseconds: 45),
    );

    // When logged, TomLoggable.logRepresentation is used
    print('   - UserAccount.logRepresentation: ${user.logRepresentation}');
    print('   - UserAccount.toString(): ${user.toString()}');
    print('   - ApiRequest.logRepresentation: ${request.logRepresentation}');

    // The logRepresentation hides sensitive data
    loggableWorks =
        user.logRepresentation.contains('john.doe') &&
        !user.logRepresentation.contains('password123');

    // Log the objects
    tomLog.info(user.logRepresentation);
    tomLog.info(request.logRepresentation);

    // Assertions
    assert(loggableWorks, 'Loggable should hide sensitive data');
    assert(!user.logRepresentation.contains('secret'), 'Should not contain sensitive data');
  }

  // --------------------------------------------------------------------------
  // Example 6: limited() helper function
  // --------------------------------------------------------------------------
  static void example6LimitedHelper() {
    print('\n6. limited() helper function:');

    final longString = 'This is a very long string that would clutter log output if not truncated';
    final shortString = 'Short';
    final nullValue = null;

    // Limit strings to prevent excessive log output
    limitedResult = limited(longString, 20);
    final shortResult = limited(shortString, 20);
    final nullResult = limited(nullValue, 20);

    print('   - Long string (${longString.length} chars):');
    print('     limited(20): $limitedResult');
    print('   - Short string (${shortString.length} chars):');
    print('     limited(20): $shortResult');
    print('   - Null value:');
    print('     limited(20): $nullResult');

    // Assertions
    assert(limitedResult.length <= 23, 'Should be limited plus ...');
    assert(limitedResult.endsWith('...'), 'Should end with ...');
    assert(shortResult == 'Short', 'Short should not be changed');
  }

  // --------------------------------------------------------------------------
  // Example 7: Global settings
  // --------------------------------------------------------------------------
  static void example7GlobalSettings() {
    print('\n7. Global logging settings:');

    // Show current global settings
    print('   - globalSettingDetermineCaller: ${TomLogger.globalSettingDetermineCaller}');
    print('   - globalSettingInfoEnabled: ${TomLogger.globalSettingInfoEnabled}');
    print('   - globalSettingWarnEnabled: ${TomLogger.globalSettingWarnEnabled}');
    print('   - globalSettingErrorEnabled: ${TomLogger.globalSettingErrorEnabled}');
    print('   - globalSettingDebugEnabled: ${TomLogger.globalSettingDebugEnabled}');
    print('   - globalSettingTraceEnabled: ${TomLogger.globalSettingTraceEnabled}');
    print('   - globalSettingTrafficEnabled: ${TomLogger.globalSettingTrafficEnabled}');
    print('   - globalSettingSevereEnabled: ${TomLogger.globalSettingSevereEnabled}');
    print('   - globalSettingFatalEnabled: ${TomLogger.globalSettingFatalEnabled}');
    print('   - globalSettingStatusEnabled: ${TomLogger.globalSettingStatusEnabled}');
    print('');
    print('   These can be toggled to completely disable certain log levels');
    print('   even if the log level pattern would normally include them.');
  }

  // --------------------------------------------------------------------------
  // Example 8: Console log output settings
  // --------------------------------------------------------------------------
  static void example8ConsoleOutputSettings() {
    print('\n8. Console log output settings:');

    // TomConsoleLogOutput has settings for stderr routing
    print('   - TomConsoleLogOutput.globalSettingStderrLogLevel');
    print('     Controls which levels go to stderr vs stdout');
    print('');
    print('   Default behavior:');
    print('   - ERROR, SEVERE, FATAL go to stderr');
    print('   - Other levels go to stdout');
    print('');
    print('   The log output format includes:');
    print('   - Timestamp');
    print('   - Log level');
    print('   - Isolate name (if applicable)');
    print('   - Origin (class.method if determineCaller is enabled)');
    print('   - Message');
  }

  // --------------------------------------------------------------------------
  // Example 9: Log level arithmetic
  // --------------------------------------------------------------------------
  static void example9LevelArithmetic() {
    print('\n9. Log level arithmetic (combining and removing levels):');

    // Combine levels with +
    final infoAndError = TomLogLevel.info + TomLogLevel.error;
    print('   - info + error pattern: ${infoAndError.levelPattern}');
    print('   - Matches info: ${infoAndError.matches(TomLogLevel.info)}');
    print('   - Matches error: ${infoAndError.matches(TomLogLevel.error)}');
    print('   - Matches debug: ${infoAndError.matches(TomLogLevel.debug)}');

    // Remove levels with -
    final productionNoWarn = TomLogLevel.production - TomLogLevel.warn;
    print('');
    print('   - production - warn pattern: ${productionNoWarn.levelPattern}');
    print('   - Matches info: ${productionNoWarn.matches(TomLogLevel.info)}');
    print('   - Matches warn: ${productionNoWarn.matches(TomLogLevel.warn)}');
    print('   - Matches error: ${productionNoWarn.matches(TomLogLevel.error)}');

    // Assertions
    assert(infoAndError.matches(TomLogLevel.info), 'Should match info');
    assert(infoAndError.matches(TomLogLevel.error), 'Should match error');
    assert(!infoAndError.matches(TomLogLevel.debug), 'Should not match debug');
    assert(!productionNoWarn.matches(TomLogLevel.warn), 'Should not match warn');
  }

  // --------------------------------------------------------------------------
  // Example 10: Predefined compound levels
  // --------------------------------------------------------------------------
  static void example10CompoundLevels() {
    print('\n10. Predefined compound log levels:');

    print('   Level           | Pattern  | Description');
    print('   ----------------|----------|----------------------------------');
    print('   development     | ${TomLogLevel.development.levelPattern.toString().padLeft(8)} | All levels including trace');
    print('   extended        | ${TomLogLevel.extended.levelPattern.toString().padLeft(8)} | Production + debug + traffic');
    print('   production      | ${TomLogLevel.production.levelPattern.toString().padLeft(8)} | info, warn, errors, status');
    print('   still           | ${TomLogLevel.still.levelPattern.toString().padLeft(8)} | warn + errors + status');
    print('   silent          | ${TomLogLevel.silent.levelPattern.toString().padLeft(8)} | errors + status only');
    print('   errors          | ${TomLogLevel.errors.levelPattern.toString().padLeft(8)} | error + severe + fatal');
    print('   off/none        | ${TomLogLevel.off.levelPattern.toString().padLeft(8)} | No logging');
    print('   all             | ${TomLogLevel.all.levelPattern.toString().padLeft(8)} | All possible levels');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('ADVANCED LOGGING CONFIGURATION EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  AdvancedLoggingExample.example1LogLevelStack();
  AdvancedLoggingExample.example2NameLevels();
  AdvancedLoggingExample.example3LogLevelExceptions();
  AdvancedLoggingExample.example4SetLevelByName();
  AdvancedLoggingExample.example5TomLoggable();
  AdvancedLoggingExample.example6LimitedHelper();
  AdvancedLoggingExample.example7GlobalSettings();
  AdvancedLoggingExample.example8ConsoleOutputSettings();
  AdvancedLoggingExample.example9LevelArithmetic();
  AdvancedLoggingExample.example10CompoundLevels();

  print('\n✓ All advanced logging examples passed!\n');
}

void main() => run();
