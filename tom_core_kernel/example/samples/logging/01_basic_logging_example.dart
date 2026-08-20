/// Demonstrates basic logging functionality using the TomLogger system.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
  static bool infoLogged = false;
  static bool debugLogged = false;
  static bool errorLogged = false;

  static void example1BasicLogMethods() {
    // Store original log level to restore later
    final originalLogLevel = tomLog.logLevel;

    // Set to development mode to see all log levels
    tomLog.setLogLevel(TomLogLevel.development);

    // Info - General runtime information
    tomLog.info('Application started successfully');
    infoLogged = true;

    // Debug - Detailed debugging information
    tomLog.debug('Processing request with id: 12345');
    debugLogged = true;

    // Error - Error conditions (recoverable)
    tomLog.error('Failed to connect to secondary database, using primary');
    errorLogged = true;

    // Restore original log level
    tomLog.setLogLevel(originalLogLevel);

    assert(infoLogged, 'Info should be logged');
    assert(debugLogged, 'Debug should be logged');
    assert(errorLogged, 'Error should be logged');
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
  static bool allLevelsExecuted = false;

  static void example6AllLogLevels() {
    final originalLogLevel = tomLog.logLevel;
    tomLog.setLogLevel(TomLogLevel.development);

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

    allLevelsExecuted = true;

    tomLog.setLogLevel(originalLogLevel);

    assert(allLevelsExecuted, 'All log levels should execute');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicLogMethodsExample.example1BasicLogMethods();
  LogObjectTypesExample.example2LogObjectTypes();
  TomLoggableExample.example3TomLoggable();
  LazyEvaluationExample.example4LazyEvaluation();
  LimitedUtilityExample.example5LimitedUtility();
  AllLogLevelsExample.example6AllLogLevels();
}

void main() => run();
