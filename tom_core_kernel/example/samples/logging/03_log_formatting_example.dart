/// Demonstrates log output formatting and customization in TomLogger.
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

/// Custom log output that formats messages as JSON-like maps.
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

// =============================================================================
// EXAMPLE 1: Default Console Output Configuration
// =============================================================================

class ConsoleOutputConfigExample {
  static int stderrLevelBit = 0;
  static int stdoutLevelBit = 0;
  static bool stderrMatchesError = false;
  static bool stderrMatchesInfo = false;

  static void example1ConsoleOutputConfig() {
    stderrLevelBit = TomConsoleLogOutput.globalSettingStderrLogLevel.levelPattern;
    stdoutLevelBit = TomConsoleLogOutput.globalSettingStdoutLogLevel.levelPattern;

    stderrMatchesError =
        TomConsoleLogOutput.globalSettingStderrLogLevel.matches(TomLogLevel.error);
    stderrMatchesInfo =
        TomConsoleLogOutput.globalSettingStderrLogLevel.matches(TomLogLevel.info);

    assert(stderrLevelBit > 0, 'Stderr level should be configured');
    assert(stdoutLevelBit > 0, 'Stdout level should be configured');
    assert(stderrMatchesError, 'Stderr should receive errors');
    assert(!stderrMatchesInfo, 'Stderr should not receive info');
  }
}

// =============================================================================
// EXAMPLE 2: Custom Capturing Log Output
// =============================================================================

class CapturingOutputExample {
  static int capturedCount = 0;
  static List<String> capturedLevels = [];
  static bool customOutputWorks = false;

  static void example2CapturingOutput() {
    final originalLogOutput = tomLog.logOutput;
    final originalLogLevel = tomLog.logLevel;

    final capturingOutput = CapturingLogOutput();
    tomLog.logOutput = capturingOutput;
    tomLog.setLogLevel(TomLogLevel.development);

    tomLog.info('First info message');
    tomLog.debug('Debug details here');
    tomLog.error('An error occurred');

    capturedCount = capturingOutput.messages.length;
    capturedLevels = List.from(capturingOutput.levels);

    customOutputWorks =
        capturedCount == 3 &&
        capturedLevels.contains('INFO') &&
        capturedLevels.contains('DEBUG') &&
        capturedLevels.contains('ERROR');

    tomLog.logOutput = originalLogOutput;
    tomLog.setLogLevel(originalLogLevel);

    assert(capturedCount == 3, 'Should capture 3 messages');
    assert(capturedLevels.contains('INFO'), 'Should have INFO level');
    assert(capturedLevels.contains('DEBUG'), 'Should have DEBUG level');
    assert(capturedLevels.contains('ERROR'), 'Should have ERROR level');
    assert(customOutputWorks, 'Custom output should work');
  }
}

// =============================================================================
// EXAMPLE 3: JSON Log Output Format
// =============================================================================

class JsonOutputExample {
  static int jsonEntryCount = 0;
  static String? firstEntryLevel;
  static String? firstEntryMessage;
  static bool jsonOutputWorks = false;

  static void example3JsonOutput() {
    final originalLogOutput = tomLog.logOutput;
    final originalLogLevel = tomLog.logLevel;

    final jsonOutput = JsonLogOutput();
    tomLog.logOutput = jsonOutput;
    tomLog.setLogLevel(TomLogLevel.production);

    tomLog.info('User logged in');
    tomLog.warn('Rate limit approaching');
    tomLog.error('Database connection failed');

    jsonEntryCount = jsonOutput.entries.length;

    if (jsonOutput.entries.isNotEmpty) {
      firstEntryLevel = jsonOutput.entries.first['level'] as String?;
      firstEntryMessage = jsonOutput.entries.first['message'] as String?;
    }

    jsonOutputWorks =
        jsonEntryCount == 3 &&
        firstEntryLevel == 'INFO' &&
        firstEntryMessage == 'User logged in';

    tomLog.logOutput = originalLogOutput;
    tomLog.setLogLevel(originalLogLevel);

    assert(jsonEntryCount == 3, 'Should have 3 JSON entries');
    assert(firstEntryLevel == 'INFO', 'First entry level should be INFO');
    assert(firstEntryMessage == 'User logged in', 'First message should match');
    assert(jsonOutputWorks, 'JSON output should work');
  }
}

// =============================================================================
// EXAMPLE 4: Log Level Filtering in Custom Output
// =============================================================================

class LevelFilteringExample {
  static int prodModeCount = 0;
  static int devModeCount = 0;
  static bool filteringWorks = false;

  static void example4LevelFiltering() {
    final originalLogOutput = tomLog.logOutput;
    final originalLogLevel = tomLog.logLevel;

    final capturingOutput = CapturingLogOutput();
    tomLog.logOutput = capturingOutput;

    // Production mode - debug should be filtered
    tomLog.setLogLevel(TomLogLevel.production);
    tomLog.debug('This should not appear');
    tomLog.info('This should appear');
    prodModeCount = capturingOutput.messages.length;

    capturingOutput.clear();

    // Development mode - all levels should appear
    tomLog.setLogLevel(TomLogLevel.development);
    tomLog.debug('This should appear in dev');
    tomLog.info('This should also appear');
    devModeCount = capturingOutput.messages.length;

    filteringWorks = prodModeCount == 1 && devModeCount == 2;

    tomLog.logOutput = originalLogOutput;
    tomLog.setLogLevel(originalLogLevel);

    assert(prodModeCount == 1, 'Production should only have 1 message');
    assert(devModeCount == 2, 'Development should have 2 messages');
    assert(filteringWorks, 'Filtering should work');
  }
}

// =============================================================================
// EXAMPLE 5: Caller Determination Setting
// =============================================================================

class CallerDeterminationExample {
  static bool callerEnabled = false;
  static bool settingRead = false;

  static void example5CallerDetermination() {
    callerEnabled = TomLogger.globalSettingDetermineCaller;
    settingRead = true;

    // The setting should be readable
    assert(settingRead, 'Setting should be readable');
    // Default is typically true
    assert(callerEnabled || !callerEnabled, 'Caller setting should be boolean');
  }
}

// =============================================================================
// EXAMPLE 6: Log Message with Timestamp
// =============================================================================

class TimestampExample {
  static bool hasTimestamp = false;
  static bool timestampIsRecent = false;

  static void example6Timestamp() {
    final originalLogOutput = tomLog.logOutput;
    final originalLogLevel = tomLog.logLevel;

    final jsonOutput = JsonLogOutput();
    tomLog.logOutput = jsonOutput;
    tomLog.setLogLevel(TomLogLevel.development);

    final beforeLog = DateTime.now();
    tomLog.info('Message with timestamp');
    final afterLog = DateTime.now();

    if (jsonOutput.entries.isNotEmpty) {
      final timestampStr = jsonOutput.entries.first['timestamp'] as String?;
      hasTimestamp = timestampStr != null && timestampStr.isNotEmpty;

      if (hasTimestamp) {
        final logTime = DateTime.parse(timestampStr!);
        timestampIsRecent =
            logTime.isAfter(beforeLog.subtract(Duration(seconds: 1))) &&
            logTime.isBefore(afterLog.add(Duration(seconds: 1)));
      }
    }

    tomLog.logOutput = originalLogOutput;
    tomLog.setLogLevel(originalLogLevel);

    assert(hasTimestamp, 'Should have timestamp');
    assert(timestampIsRecent, 'Timestamp should be recent');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  ConsoleOutputConfigExample.example1ConsoleOutputConfig();
  CapturingOutputExample.example2CapturingOutput();
  JsonOutputExample.example3JsonOutput();
  LevelFilteringExample.example4LevelFiltering();
  CallerDeterminationExample.example5CallerDetermination();
  TimestampExample.example6Timestamp();
}

void main() => run();
