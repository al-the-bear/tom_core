/// Demonstrates basic logging functionality using the TomLogger system.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

/// Collects the records the logger emitted, so a sample can assert what
/// reached the output rather than that the call returned.
///
/// A logging sample that only records "I called `info`" proves the method
/// exists. What the reader needs to know is that the call produced a record, at
/// the level asked for, carrying the message given — and that a level below the
/// threshold produces none.
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
    if (!logLevel.matches(loggerLevel)) return;
    messages.add(convertToString(message));
    levels.add(level.trim());
  }
}

/// Example class implementing TomLoggable for custom log representation.
class User implements TomLoggable {
  final String id;
  final String name;
  final String email;

  User(this.id, this.name, this.email);

  @override
  String get logRepresentation => 'User(id=$id, name=$name)';

  @override
  String toString() => 'User{id: $id, name: $name, email: $email}';
}

// =============================================================================
// EXAMPLE 1: Basic Log Methods
// =============================================================================

class BasicLogMethodsExample {
  static List<String> recordedLevels = const [];
  static List<String> recordedMessages = const [];

  static void example1BasicLogMethods() {
    // Store original log level and output to restore later
    final originalLogLevel = tomLog.logLevel;
    final originalLogOutput = tomLog.logOutput;

    final captured = CapturingLogOutput();
    tomLog.logOutput = captured;

    // Set to development mode to see all log levels
    tomLog.setLogLevel(TomLogLevel.development);

    // Info - General runtime information
    tomLog.info('Application started successfully');

    // Debug - Detailed debugging information
    tomLog.debug('Processing request with id: 12345');

    // Error - Error conditions (recoverable)
    tomLog.error('Failed to connect to secondary database, using primary');

    // Restore original log level and output
    tomLog.setLogLevel(originalLogLevel);
    tomLog.logOutput = originalLogOutput;

    recordedLevels = captured.levels;
    recordedMessages = captured.messages;

    assert(
      recordedLevels.join(',') == 'INFO,DEBUG,ERROR',
      'The three calls should reach the output at their own levels, in order',
    );
    assert(
      recordedMessages.first == 'Application started successfully',
      'The record should carry the message the call was given',
    );
  }
}

// =============================================================================
// EXAMPLE 2: Logging Different Object Types
// =============================================================================

class LogObjectTypesExample {
  static String? stringMessage;
  static int? numericValue;
  static Map<String, dynamic>? configMap;
  static List<String>? items;

  static void example2LogObjectTypes() {
    final originalLogLevel = tomLog.logLevel;
    tomLog.setLogLevel(TomLogLevel.development);

    // Strings
    stringMessage = 'Simple string message';
    tomLog.info(stringMessage!);

    // Numbers
    numericValue = 42;
    tomLog.debug('The answer is: $numericValue');

    // Maps/Objects
    configMap = {'host': 'localhost', 'port': 8080, 'debug': true};
    tomLog.info('Configuration: $configMap');

    // Lists
    items = ['apple', 'banana', 'cherry'];
    tomLog.debug('Processing items: $items');

    tomLog.setLogLevel(originalLogLevel);

    assert(stringMessage == 'Simple string message', 'String should be set');
    assert(numericValue == 42, 'Numeric value should be 42');
    assert(configMap!['port'] == 8080, 'Port should be 8080');
    assert(items!.length == 3, 'Should have 3 items');
  }
}

// =============================================================================
// EXAMPLE 3: TomLoggable Interface
// =============================================================================

class TomLoggableExample {
  static String? userToString;
  static String? userLogRepr;
  static bool emailExcluded = false;

  static void example3TomLoggable() {
    final user = User('usr_001', 'John Doe', 'john@example.com');

    // Normal toString() - includes all fields
    userToString = user.toString();

    // logRepresentation - controlled output for logs (excludes sensitive data)
    userLogRepr = user.logRepresentation;

    // Email should be excluded from log representation
    emailExcluded = !userLogRepr!.contains('email');

    assert(
      userLogRepr == 'User(id=usr_001, name=John Doe)',
      'Log repr should match',
    );
    assert(emailExcluded, 'Email should be excluded from log representation');
    assert(userToString!.contains('email'), 'toString should contain email');
  }
}

// =============================================================================
// EXAMPLE 4: Lazy Evaluation with Functions
// =============================================================================

class LazyEvaluationExample {
  static int evaluationCount = 0;
  static int afterDevEval = 0;
  static int afterProdEval = 0;
  static bool lazyEvaluationWorks = false;

  static void example4LazyEvaluation() {
    final originalLogLevel = tomLog.logLevel;
    evaluationCount = 0;

    String expensiveOperation() {
      evaluationCount++;
      return 'Expensive result computed (count: $evaluationCount)';
    }

    // With development level, this WILL be evaluated
    tomLog.setLogLevel(TomLogLevel.development);
    tomLog.debug(() => expensiveOperation());

    afterDevEval = evaluationCount;

    // With production level, debug messages are filtered out
    // and the function is NOT called (efficient lazy evaluation)
    tomLog.setLogLevel(TomLogLevel.production);
    tomLog.debug(() => expensiveOperation());

    afterProdEval = evaluationCount;

    lazyEvaluationWorks = afterDevEval == 1 && afterProdEval == 1;

    tomLog.setLogLevel(originalLogLevel);

    assert(afterDevEval == 1, 'Should evaluate once in development mode');
    assert(afterProdEval == 1, 'Should not evaluate when filtered (lazy)');
    assert(lazyEvaluationWorks, 'Lazy evaluation should work');
  }
}

// =============================================================================
// EXAMPLE 5: The limited() Utility Function
// =============================================================================

class LimitedUtilityExample {
  static String? truncated20;
  static String? truncated50;
  static int originalLength = 0;
  static bool truncationWorks = false;

  static void example5LimitedUtility() {
    final longMessage =
        'This is a very long message that contains a lot of information '
        'and would be too verbose to display in logs, so we can truncate it.';

    originalLength = longMessage.length;
    truncated20 = limited(longMessage, 20);
    truncated50 = limited(longMessage, 50);

    truncationWorks =
        truncated20!.length <= 20 + 3 && // +3 for "..."
        truncated50!.length <= 50 + 3;

    assert(originalLength > 50, 'Original should be longer than 50');
    assert(
      truncated20!.length < originalLength,
      'Truncated 20 should be shorter',
    );
    assert(
      truncated50!.length < originalLength,
      'Truncated 50 should be shorter',
    );
    assert(truncationWorks, 'Truncation should work');
  }
}

// =============================================================================
// EXAMPLE 6: All Log Levels
// =============================================================================

class AllLogLevelsExample {
  /// The level label of every record the nine calls produced, in order.
  static List<String> levelsAtDevelopment = const [];

  /// The same nine calls with the logger at `TomLogLevel.production`.
  static List<String> levelsAtProduction = const [];

  static void example6AllLogLevels() {
    final originalLogLevel = tomLog.logLevel;
    final originalLogOutput = tomLog.logOutput;

    // One call per level, in order of increasing severity.
    void logAtEveryLevel() {
      // Trace - Very detailed tracing (most verbose)
      tomLog.trace('Entering method processData');

      // Debug - Detailed debugging information
      tomLog.debug('Processing request');

      // Traffic - Network/data flow logging
      tomLog.traffic('HTTP GET /api/users -> 200 OK');

      // Info - General runtime information
      tomLog.info('Application event');

      // Warn - Potentially problematic situations
      tomLog.warn('Cache miss');

      // Status - Important status updates
      tomLog.status('Configuration loaded');

      // Error - Error conditions (recoverable)
      tomLog.error('Connection failed');

      // Severe - Serious errors
      tomLog.severe('Memory threshold exceeded');

      // Fatal - Critical errors
      tomLog.fatal('Unable to initialize');
    }

    final atDevelopment = CapturingLogOutput();
    tomLog.logOutput = atDevelopment;
    tomLog.setLogLevel(TomLogLevel.development);
    logAtEveryLevel();

    final atProduction = CapturingLogOutput();
    tomLog.logOutput = atProduction;
    tomLog.setLogLevel(TomLogLevel.production);
    logAtEveryLevel();

    tomLog.setLogLevel(originalLogLevel);
    tomLog.logOutput = originalLogOutput;

    levelsAtDevelopment = atDevelopment.levels;
    levelsAtProduction = atProduction.levels;

    assert(
      levelsAtDevelopment.join(',') ==
          'TRACE,DEBUG,TRAFFIC,INFO,WARN,STATUS,ERROR,SEVERE,FATAL',
      'Development should let every level through, in call order',
    );

    // What a log level *does* is drop records, so the second run is the half of
    // the demonstration that can fail: production is development without the
    // three diagnostic levels, and the same nine calls have to yield six.
    assert(
      levelsAtProduction.join(',') == 'INFO,WARN,STATUS,ERROR,SEVERE,FATAL',
      'Production should drop trace, debug and traffic',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 01: Basic Logging Example ===\n');

  BasicLogMethodsExample.example1BasicLogMethods();
  print('1. The records the three calls produced, captured off the output:');
  print('   levels           : ${BasicLogMethodsExample.recordedLevels}');
  print(
    '   first message    : ${BasicLogMethodsExample.recordedMessages.first}',
  );
  print('');

  LogObjectTypesExample.example2LogObjectTypes();
  print('2. The values the four lines above interpolated into their message:');
  print('   string           : ${LogObjectTypesExample.stringMessage}');
  print('   number           : ${LogObjectTypesExample.numericValue}');
  print('   map              : ${LogObjectTypesExample.configMap}');
  print('   list             : ${LogObjectTypesExample.items}');
  print('');

  TomLoggableExample.example3TomLoggable();
  print('3. TomLoggable lets an object keep secrets out of the log:');
  print('   toString()       : ${TomLoggableExample.userToString}');
  print('   logRepresentation: ${TomLoggableExample.userLogRepr}');
  print('   email left out   : ${TomLoggableExample.emailExcluded}');
  print('');

  LazyEvaluationExample.example4LazyEvaluation();
  print('4. A closure message is only evaluated if the level lets it through:');
  print(
    '   evaluations after the development-level call: '
    '${LazyEvaluationExample.afterDevEval}',
  );
  print(
    '   evaluations after the production-level call : '
    '${LazyEvaluationExample.afterProdEval}',
  );
  print(
    '   the filtered call never ran the closure     : '
    '${LazyEvaluationExample.lazyEvaluationWorks}',
  );
  print('');

  LimitedUtilityExample.example5LimitedUtility();
  print('5. limited() shortens a value before it reaches the log:');
  print('   original length  : ${LimitedUtilityExample.originalLength}');
  print('   limited to 20    : ${LimitedUtilityExample.truncated20}');
  print('   limited to 50    : ${LimitedUtilityExample.truncated50}');
  print('   stayed in budget : ${LimitedUtilityExample.truncationWorks}');
  print('');

  AllLogLevelsExample.example6AllLogLevels();
  print('6. One call per level, run twice — the level decides what survives:');
  print('   at development: ${AllLogLevelsExample.levelsAtDevelopment}');
  print('   at production : ${AllLogLevelsExample.levelsAtProduction}');
  print('');
}

void main() {
  requireAsserts();
  run();
}
