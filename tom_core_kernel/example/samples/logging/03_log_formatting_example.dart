/// Demonstrates log output formatting and customization in TomLogger.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/logging/03_log_formatting_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// Custom log output that captures messages for testing/demonstration.
class CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  final List<String> levels = [];

  /// The caller of each captured record, in order.
  ///
  /// Kept separately from the formatted line because it is the one field that
  /// is *absent* rather than wrong when caller determination is off, and the
  /// empty string is invisible once folded into a formatted string.
  final List<String> origins = [];

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
      origins.add(origin ?? '');
    }
  }

  void clear() {
    messages.clear();
    levels.clear();
    origins.clear();
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
    stderrLevelBit =
        TomConsoleLogOutput.globalSettingStderrLogLevel.levelPattern;
    stdoutLevelBit =
        TomConsoleLogOutput.globalSettingStdoutLogLevel.levelPattern;

    stderrMatchesError = TomConsoleLogOutput.globalSettingStderrLogLevel
        .matches(TomLogLevel.error);
    stderrMatchesInfo = TomConsoleLogOutput.globalSettingStderrLogLevel.matches(
      TomLogLevel.info,
    );

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
  static String? firstCapturedMessage;
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
    firstCapturedMessage = capturingOutput.messages.isNotEmpty
        ? capturingOutput.messages.first
        : null;

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
  static String originWhenEnabled = '';
  static String originWhenDisabled = '';

  static void example5CallerDetermination() {
    final originalLogOutput = tomLog.logOutput;
    final originalLogLevel = tomLog.logLevel;
    final originalDetermineCaller = TomLogger.globalSettingDetermineCaller;

    final capturingOutput = CapturingLogOutput();
    tomLog.logOutput = capturingOutput;
    tomLog.setLogLevel(TomLogLevel.production);

    // On: every log call walks its own stack and stamps the record with the
    // member it was called from.
    TomLogger.globalSettingDetermineCaller = true;
    tomLog.info('called with caller determination on');
    originWhenEnabled = capturingOutput.origins.last;

    // Off: the walk is skipped, so the record carries no origin at all. That
    // walk is the expensive part of a log call, which is the whole reason the
    // setting exists — and why per-name log levels stop working with it off,
    // since they are keyed by the caller it no longer determines.
    TomLogger.globalSettingDetermineCaller = false;
    tomLog.info('called with caller determination off');
    originWhenDisabled = capturingOutput.origins.last;

    TomLogger.globalSettingDetermineCaller = originalDetermineCaller;
    tomLog.logOutput = originalLogOutput;
    tomLog.setLogLevel(originalLogLevel);

    assert(
      originWhenEnabled.contains('CallerDeterminationExample'),
      'Origin should name the calling member when determination is on',
    );
    assert(
      originWhenDisabled.isEmpty,
      'Origin should be absent when determination is off',
    );
  }
}

// =============================================================================
// EXAMPLE 6: Log Message with Timestamp
// =============================================================================

class TimestampExample {
  static bool hasTimestamp = false;
  static bool timestampIsRecent = false;
  static String? loggedTimestamp;

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
      loggedTimestamp = timestampStr;
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
  print('=== 03: Log Formatting Example ===\n');

  ConsoleOutputConfigExample.example1ConsoleOutputConfig();
  print('1. The console output splits the levels across stderr and stdout:');
  print('   stderr level bits: ${ConsoleOutputConfigExample.stderrLevelBit}');
  print('   stdout level bits: ${ConsoleOutputConfigExample.stdoutLevelBit}');
  print(
    '   stderr takes error: '
    '${ConsoleOutputConfigExample.stderrMatchesError}',
  );
  print(
    '   stderr takes info : '
    '${ConsoleOutputConfigExample.stderrMatchesInfo}',
  );
  print('');

  CapturingOutputExample.example2CapturingOutput();
  print(
    '2. A custom TomLogOutput receives the records instead of the console:',
  );
  print('   records captured : ${CapturingOutputExample.capturedCount}');
  print('   their levels     : ${CapturingOutputExample.capturedLevels}');
  print('   first record as this output formats it:');
  print('     ${CapturingOutputExample.firstCapturedMessage}');
  print('');

  JsonOutputExample.example3JsonOutput();
  print('3. The same records, formatted as JSON-like maps instead of lines:');
  print('   entries          : ${JsonOutputExample.jsonEntryCount}');
  print('   first level      : ${JsonOutputExample.firstEntryLevel}');
  print('   first message    : ${JsonOutputExample.firstEntryMessage}');
  print('');

  LevelFilteringExample.example4LevelFiltering();
  print('4. The logger level decides what ever reaches the output at all:');
  print(
    '   production: debug + info sent, records arrived: '
    '${LevelFilteringExample.prodModeCount}',
  );
  print(
    '   development: debug + info sent, records arrived: '
    '${LevelFilteringExample.devModeCount}',
  );
  print('   filtering worked : ${LevelFilteringExample.filteringWorks}');
  print('');

  CallerDeterminationExample.example5CallerDetermination();
  print('5. Caller determination stamps each record with its calling member:');
  print('   with it on : "${CallerDeterminationExample.originWhenEnabled}"');
  print('   with it off: "${CallerDeterminationExample.originWhenDisabled}"');
  print('');

  TimestampExample.example6Timestamp();
  print('6. Every record is stamped with the time it was logged:');
  print('   timestamp        : ${TimestampExample.loggedTimestamp}');
  print('   timestamp present: ${TimestampExample.hasTimestamp}');
  print(
    '   within the window around the call: '
    '${TimestampExample.timestampIsRecent}',
  );
  print('');
}

void main() {
  prepareSampleProcess();
  run();
}
