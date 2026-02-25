/// Demonstrates JSON serialization utilities including pretty printing
/// and JSON formatting for human-readable output.
///
/// This example covers:
/// - Converting compact JSON to pretty-printed format with indentation
/// - Converting JSON to single-line formatted output
/// - Working with nested JSON structures
/// - Handling various JSON data types (strings, numbers, booleans, arrays)
///
/// These utilities are useful for:
/// - Logging and debugging JSON data
/// - Displaying configuration files
/// - API response inspection
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 01: JSON Serialization Example ===\n');

  // ===========================================================================
  // Example 1: Basic Pretty Printing
  // ===========================================================================

  print('1. Basic pretty printing of compact JSON:');

  final compactJson = '{"name":"MyApp","version":"1.0.0","enabled":true}';
  final prettyOutput = prettyJson(compactJson);

  print('   Input (compact):');
  print('   $compactJson');
  print('   Output (pretty):');
  for (final line in prettyOutput.split('\n')) {
    print('   $line');
  }
  print('');

  // ===========================================================================
  // Example 2: Nested JSON Structures
  // ===========================================================================

  print('2. Pretty printing nested JSON structures:');

  final nestedJson =
      '{"database":{"host":"localhost","port":5432,"settings":{"pool_size":10,"timeout":30}},"cache":{"enabled":true}}';
  final prettyNested = prettyJson(nestedJson);

  print('   Input (compact):');
  print('   $nestedJson');
  print('   Output (pretty):');
  for (final line in prettyNested.split('\n')) {
    print('   $line');
  }
  print('');

  // ===========================================================================
  // Example 3: JSON with Arrays
  // ===========================================================================

  print('3. Pretty printing JSON with arrays:');

  final arrayJson =
      '{"features":["auth","logging","metrics"],"servers":[{"name":"primary","port":8080},{"name":"backup","port":8081}]}';
  final prettyArray = prettyJson(arrayJson);

  print('   Input (compact):');
  print('   $arrayJson');
  print('   Output (pretty):');
  for (final line in prettyArray.split('\n')) {
    print('   $line');
  }
  print('');

  // ===========================================================================
  // Example 4: Single-Line Pretty Format
  // ===========================================================================

  print('4. Converting JSON to single-line pretty format:');

  final simpleJson = '{"a":1,"b":2,"c":3}';
  final oneLineOutput = prettyJsonLine(simpleJson);

  print('   Input: $simpleJson');
  print('   Output (one line): $oneLineOutput');
  print('');

  // ===========================================================================
  // Example 5: Complex Single-Line Format
  // ===========================================================================

  print('5. Single-line format for complex nested JSON:');

  final complexJson = '{"user":{"id":123,"name":"Alice"},"active":true}';
  final oneLineComplex = prettyJsonLine(complexJson);

  print('   Input: $complexJson');
  print('   Output (one line): $oneLineComplex');
  print('');

  // ===========================================================================
  // Example 6: Using the Indent Encoder Directly
  // ===========================================================================

  print('6. Using indentEncoder with Dart objects:');

  final dartMap = {
    'application': 'tom_core',
    'modules': ['json', 'crypto', 'timezoned'],
    'config': {'debug': false, 'logLevel': 'info'},
  };
  final encodedFromMap = indentEncoder.convert(dartMap);

  print('   Dart Map encoded to pretty JSON:');
  for (final line in encodedFromMap.split('\n')) {
    print('   $line');
  }
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: Basic pretty printing
  assert(prettyOutput.contains('"name": "MyApp"'));
  assert(prettyOutput.contains('"version": "1.0.0"'));
  assert(prettyOutput.contains('"enabled": true'));
  assert(prettyOutput.split('\n').length > 1); // Multi-line output

  // Example 2: Nested JSON structures
  assert(prettyNested.contains('"host": "localhost"'));
  assert(prettyNested.contains('"port": 5432'));
  assert(prettyNested.contains('"pool_size": 10'));
  assert(prettyNested.contains('"timeout": 30'));
  assert(prettyNested.contains('"enabled": true'));

  // Example 3: JSON with arrays
  assert(prettyArray.contains('"auth"'));
  assert(prettyArray.contains('"logging"'));
  assert(prettyArray.contains('"metrics"'));
  assert(prettyArray.contains('"primary"'));
  assert(prettyArray.contains('"backup"'));

  // Example 4: Single-line pretty format
  assert(oneLineOutput.contains('"a": 1'));
  assert(oneLineOutput.contains('"b": 2'));
  assert(oneLineOutput.contains('"c": 3'));
  assert(!oneLineOutput.contains('\n')); // No newlines

  // Example 5: Complex single-line format
  assert(oneLineComplex.contains('"id": 123'));
  assert(oneLineComplex.contains('"name": "Alice"'));
  assert(oneLineComplex.contains('"active": true'));
  assert(!oneLineComplex.contains('\n')); // No newlines

  // Example 6: Indent encoder with Dart objects
  assert(encodedFromMap.contains('"application": "tom_core"'));
  assert(encodedFromMap.contains('"json"'));
  assert(encodedFromMap.contains('"debug": false'));
  assert(encodedFromMap.contains('"logLevel": "info"'));
}
