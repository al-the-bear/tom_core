/// Demonstrates log output formatting and customization in TomLogger.
///
/// This example covers:
/// - TomConsoleLogOutput configuration
/// - stdout vs stderr routing based on log levels
/// - Custom log output implementations
/// - Caller determination and origin tracking
/// - Understanding the log message format
///
/// The logging system provides flexible output formatting with
/// configurable routing to stdout/stderr and support for custom
/// output implementations.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Custom log output that captures messages for testing/demonstration.
class CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  final List<String> levels = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      final formatted =
          '$timeStamp $isolateName $level ${convertToString(message)}'
          '${origin != null ? ' [$origin]' : ''}';
      messages.add(formatted);
      levels.add(level.trim());
    }
  }

  void clear() {
    messages.clear();
    levels.clear();
  }
}

/// Custom log output that formats messages as JSON.
class JsonLogOutput extends TomLogOutput {
  final List<Map<String, dynamic>> entries = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (logLevel.matches(loggerLevel)) {
      entries.add({
        'timestamp': timeStamp.toIso8601String(),
        'level': level.trim(),
        'message': convertToString(message),
        'isolate': isolateName,
        if (origin != null) 'origin': origin,
      });
    }
  }
}

void run() {
  print('=== 03: Log Formatting Example ===\n');

  // Store original settings
  final originalLogOutput = tomLog.logOutput;
  final originalLogLevel = tomLog.logLevel;

  // ===========================================================================
  // Example 1: Default Console Output Configuration
  // ===========================================================================

  print('1. Default TomConsoleLogOutput configuration:');

  final stderrLevelBit = TomConsoleLogOutput.globalSettingStderrLogLevel.levelPattern;
  final stdoutLevelBit = TomConsoleLogOutput.globalSettingStdoutLogLevel.levelPattern;

  print('   stderr receives: errors + status (pattern: $stderrLevelBit)');
  print('   stdout receives: all other levels (pattern: $stdoutLevelBit)');
  print('');

  final stderrMatchesError = TomConsoleLogOutput.globalSettingStderrLogLevel.matches(TomLogLevel.error);
  final stderrMatchesInfo = TomConsoleLogOutput.globalSettingStderrLogLevel.matches(TomLogLevel.info);
  final stdoutMatchesInfo = TomConsoleLogOutput.globalSettingStdoutLogLevel.matches(TomLogLevel.info);
  final stdoutMatchesError = TomConsoleLogOutput.globalSettingStdoutLogLevel.matches(TomLogLevel.error);

  print('   stderr matches error? $stderrMatchesError');
  print('   stderr matches info?  $stderrMatchesInfo');
  print('   stdout matches info?  $stdoutMatchesInfo');
  print('   stdout matches error? $stdoutMatchesError');
  print('');

  // ===========================================================================
  // Example 2: Understanding Log Message Format
  // ===========================================================================

  print('2. Understanding the log message format:');

  print('   Format: <timestamp> <platform>-<isolate> <level> <message> [<origin>]');
  print('');
  print('   Components:');
  print('   - timestamp: ISO 8601 format (2024-01-15T10:30:00.000Z)');
  print('   - platform:  Platform identifier (vm, web, etc.)');
  print('   - isolate:   Isolate name (main, worker-1, etc.)');
  print('   - level:     Log level string (INFO, DEBUG, ERROR, etc.)');
  print('   - message:   The actual log message content');
  print('   - origin:    Optional caller info [ClassName.methodName]');
  print('');

  // ===========================================================================
  // Example 3: Custom Capturing Log Output
  // ===========================================================================

  print('3. Using a custom capturing log output:');

  final capturingOutput = CapturingLogOutput();
  tomLog.logOutput = capturingOutput;
  tomLog.setLogLevel(TomLogLevel.development);

  tomLog.info('First info message');
  tomLog.debug('Debug details here');
  tomLog.error('An error occurred');

  final capturedCount = capturingOutput.messages.length;
  final capturedLevels = capturingOutput.levels;

  print('   Captured $capturedCount messages');
  print('   Levels captured: $capturedLevels');

  // Show first captured message (truncated)
  if (capturingOutput.messages.isNotEmpty) {
    final firstMsg = capturingOutput.messages.first;
    final truncatedMsg = limited(firstMsg, 70);
    print('   First message: $truncatedMsg');
  }
  print('');

  // ===========================================================================
  // Example 4: JSON Log Output Format
  // ===========================================================================

  print('4. Custom JSON log output format:');

  final jsonOutput = JsonLogOutput();
  tomLog.logOutput = jsonOutput;
  tomLog.setLogLevel(TomLogLevel.production);

  tomLog.info('User logged in');
  tomLog.warn('Rate limit approaching');
  tomLog.error('Database connection failed');

  final jsonEntryCount = jsonOutput.entries.length;
  print('   Captured $jsonEntryCount JSON entries');

  if (jsonOutput.entries.isNotEmpty) {
    final firstEntry = jsonOutput.entries.first;
    final entryLevel = firstEntry['level'];
    final entryMessage = firstEntry['message'];
    print('   First entry level: $entryLevel');
    print('   First entry message: $entryMessage');
  }
  print('');

  // ===========================================================================
  // Example 5: Caller Determination Setting
  // ===========================================================================

  print('5. Caller determination setting:');

  final callerEnabled = TomLogger.globalSettingDetermineCaller;
  print('   globalSettingDetermineCaller: $callerEnabled');
  print('');
  print('   When true (default):');
  print('   - Stack trace is analyzed to find caller');
  print('   - Origin (class.method) is included in output');
  print('   - Per-name log levels work');
  print('');
  print('   When false:');
  print('   - Better performance (no stack analysis)');
  print('   - No origin in output');
  print('   - Per-name log levels do not work');
  print('');

  // ===========================================================================
  // Example 6: Log Level String Constants
  // ===========================================================================

  print('6. Log level string constants (for consistent formatting):');

  final infoStr = TomLogger.INFO;
  final errorStr = TomLogger.ERROR;
  final warnStr = TomLogger.WARN;
  final debugStr = TomLogger.DEBUG;
  final traceStr = TomLogger.TRACE;
  final trafficStr = TomLogger.TRAFFIC;
  final severeStr = TomLogger.SEVERE;
  final fatalStr = TomLogger.FATAL;
  final statusStr = TomLogger.STATUS;

  print('   INFO:    "$infoStr" (length: ${infoStr.length})');
  print('   ERROR:   "$errorStr" (length: ${errorStr.length})');
  print('   WARN:    "$warnStr" (length: ${warnStr.length})');
  print('   DEBUG:   "$debugStr" (length: ${debugStr.length})');
  print('   TRACE:   "$traceStr" (length: ${traceStr.length})');
  print('   TRAFFIC: "$trafficStr" (length: ${trafficStr.length})');
  print('   SEVERE:  "$severeStr" (length: ${severeStr.length})');
  print('   FATAL:   "$fatalStr" (length: ${fatalStr.length})');
  print('   STATUS:  "$statusStr" (length: ${statusStr.length})');
  print('');
  print('   All strings are padded to 7 characters for aligned output.');
  print('');

  // ===========================================================================
  // Example 7: Message Conversion with convertToString
  // ===========================================================================

  print('7. Message conversion behavior:');

  final testOutput = CapturingLogOutput();

  // Test string passthrough
  final stringResult = testOutput.convertToString('Hello World');
  print('   String input: "Hello World" -> "$stringResult"');

  // Test function evaluation
  final funcResult = testOutput.convertToString(() => 'Lazy value');
  print('   Function input: () => "Lazy value" -> "$funcResult"');

  // Test object toString
  final objResult = testOutput.convertToString({'key': 'value'});
  print('   Map input: {key: value} -> "$objResult"');

  // Test TomLoggable
  final loggable = _DemoLoggable();
  final loggableResult = testOutput.convertToString(loggable);
  print('   TomLoggable input: uses logRepresentation -> "$loggableResult"');
  print('');

  // ===========================================================================
  // Example 8: Remote Log Endpoint Configuration
  // ===========================================================================

  print('8. Remote log endpoint configuration:');

  final defaultEndpoint = TomLogOutput.globalSettingRemoteLogEndpoint;
  print('   Default remote endpoint: "$defaultEndpoint"');
  print('');
  print('   This endpoint is used by TomRemoteLogOutput to send');
  print('   log messages to a centralized logging server.');
  print('');

  // Restore original settings
  tomLog.logOutput = originalLogOutput;
  tomLog.setLogLevel(originalLogLevel);

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Console output configuration
  assert(stderrMatchesError == true);
  assert(stderrMatchesInfo == false);
  assert(stdoutMatchesInfo == true);
  assert(stdoutMatchesError == false);

  // Example 3: Capturing output
  assert(capturedCount == 3);
  assert(capturedLevels.contains('INFO'));
  assert(capturedLevels.contains('DEBUG'));
  assert(capturedLevels.contains('ERROR'));

  // Example 4: JSON output
  assert(jsonEntryCount == 3);
  assert(jsonOutput.entries[0]['level'] == 'INFO');
  assert(jsonOutput.entries[0]['message'] == 'User logged in');
  assert(jsonOutput.entries[1]['level'] == 'WARN');
  assert(jsonOutput.entries[2]['level'] == 'ERROR');

  // Example 5: Caller determination
  assert(callerEnabled == true);

  // Example 6: Level string constants
  assert(infoStr.length == 7);
  assert(errorStr.length == 7);
  assert(warnStr.length == 7);
  assert(debugStr.length == 7);
  assert(traceStr.length == 7);
  assert(trafficStr.length == 7);
  assert(severeStr.length == 7);
  assert(fatalStr.length == 7);
  assert(statusStr.length == 7);

  // Example 7: Message conversion
  assert(stringResult == 'Hello World');
  assert(funcResult == 'Lazy value');
  assert(objResult == '{key: value}');
  assert(loggableResult == 'DemoLoggable[custom]');

  // Example 8: Remote endpoint
  assert(defaultEndpoint == '/remotelog');
}

/// Helper class for demonstrating TomLoggable.
class _DemoLoggable implements TomLoggable {
  @override
  String get logRepresentation => 'DemoLoggable[custom]';

  @override
  String toString() => 'DemoLoggable{full details}';
}
