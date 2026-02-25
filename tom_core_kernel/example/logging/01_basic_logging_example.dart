/// Demonstrates basic logging functionality using the TomLogger system.
///
/// This example covers:
/// - Using the global tomLog instance for logging
/// - Different log level methods (info, debug, warn, error, etc.)
/// - Understanding log message format and output
/// - The TomLoggable interface for custom object representation
///
/// The logging system provides a flexible, configurable logging mechanism
/// with support for multiple log levels and pluggable output destinations.
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

void run() {
  print('=== 01: Basic Logging Example ===\n');

  // Store original log level to restore later
  final originalLogLevel = tomLog.logLevel;

  // Set to development mode to see all log levels
  tomLog.setLogLevel(TomLogLevel.development);

  // ===========================================================================
  // Example 1: Basic Log Methods
  // ===========================================================================

  print('1. Using different log methods:');
  print('   (Note: Output goes to stdout/stderr with timestamps)\n');

  // Info - General runtime information
  tomLog.info('Application started successfully');

  // Debug - Detailed debugging information
  tomLog.debug('Processing request with id: 12345');

  // Trace - Very detailed tracing (most verbose)
  tomLog.trace('Entering method processData with params: {x: 1, y: 2}');

  // Traffic - Network/data flow logging
  tomLog.traffic('HTTP GET /api/users -> 200 OK (45ms)');

  // Warn - Potentially problematic situations
  tomLog.warn('Cache miss for key: user_preferences');

  // Error - Error conditions (recoverable)
  tomLog.error('Failed to connect to secondary database, using primary');

  // Severe - Serious errors
  tomLog.severe('Memory usage exceeded 90% threshold');

  // Fatal - Critical errors that may cause termination
  tomLog.fatal('Unable to initialize core service');

  // Status - Important status updates
  tomLog.status('Configuration loaded from environment');

  print('');
  print('   All log methods demonstrated above output to console.');
  print('');

  // ===========================================================================
  // Example 2: Logging Different Object Types
  // ===========================================================================

  print('2. Logging different object types:');

  // Strings
  final stringMessage = 'Simple string message';
  tomLog.info(stringMessage);

  // Numbers
  final numericValue = 42;
  tomLog.debug('The answer is: $numericValue');

  // Maps/Objects
  final configMap = {'host': 'localhost', 'port': 8080, 'debug': true};
  tomLog.info('Configuration: $configMap');

  // Lists
  final items = ['apple', 'banana', 'cherry'];
  tomLog.debug('Processing items: $items');

  print('');

  // ===========================================================================
  // Example 3: TomLoggable Interface
  // ===========================================================================

  print('3. Using TomLoggable for custom object logging:');

  final user = User('usr_001', 'John Doe', 'john@example.com');

  // Normal toString() - includes all fields
  final userToString = user.toString();
  print('   user.toString(): $userToString');

  // logRepresentation - controlled output for logs (excludes sensitive data)
  final userLogRepr = user.logRepresentation;
  print('   user.logRepresentation: $userLogRepr');

  // When logged, TomLoggable objects use logRepresentation
  tomLog.info(user);

  print('');
  print('   TomLoggable allows objects to control their log representation,');
  print('   useful for hiding sensitive data like email addresses.');
  print('');

  // ===========================================================================
  // Example 4: Lazy Evaluation with Functions
  // ===========================================================================

  print('4. Lazy evaluation with function messages:');

  var evaluationCount = 0;

  String expensiveOperation() {
    evaluationCount++;
    return 'Expensive result computed (count: $evaluationCount)';
  }

  // With development level, this WILL be evaluated
  tomLog.setLogLevel(TomLogLevel.development);
  tomLog.debug(() => expensiveOperation());

  final afterDevEval = evaluationCount;
  print('   After debug with development level: evaluationCount = $afterDevEval');

  // With production level, debug messages are filtered out
  // and the function is NOT called (efficient lazy evaluation)
  tomLog.setLogLevel(TomLogLevel.production);
  tomLog.debug(() => expensiveOperation());

  final afterProdEval = evaluationCount;
  print('   After debug with production level: evaluationCount = $afterProdEval');
  print('   (Function not called when log level filters out the message)');
  print('');

  // ===========================================================================
  // Example 5: The limited() Utility Function
  // ===========================================================================

  print('5. Using limited() for truncating long strings:');

  final longMessage =
      'This is a very long message that contains a lot of information '
      'and would be too verbose to display in logs, so we can truncate it.';

  final truncated20 = limited(longMessage, 20);
  final truncated50 = limited(longMessage, 50);
  final truncatedFull = limited(longMessage, 200);

  print('   Original length: ${longMessage.length} characters');
  print('   limited(msg, 20): "$truncated20"');
  print('   limited(msg, 50): "$truncated50"');
  print('   limited(msg, 200): shows full (no truncation needed)');
  print('');

  // Restore original log level
  tomLog.setLogLevel(originalLogLevel);

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Basic log methods - no assertions (output-based)

  // Example 2: Logging different object types
  assert(stringMessage == 'Simple string message');
  assert(numericValue == 42);
  assert(configMap['port'] == 8080);
  assert(items.length == 3);

  // Example 3: TomLoggable interface
  assert(user.id == 'usr_001');
  assert(user.name == 'John Doe');
  assert(userLogRepr == 'User(id=usr_001, name=John Doe)');
  assert(!userLogRepr.contains('email')); // Email should be excluded

  // Example 4: Lazy evaluation
  assert(afterDevEval == 1); // Evaluated once in development mode
  assert(afterProdEval == 1); // Function NOT called when filtered (lazy!)

  // Example 5: limited() utility
  assert(truncated20 == 'This is a very long ...');
  assert(truncated50.endsWith('...'));
  assert(truncated50.length == 53); // 50 chars + "..."
  assert(truncatedFull == longMessage); // No truncation when under limit
}
