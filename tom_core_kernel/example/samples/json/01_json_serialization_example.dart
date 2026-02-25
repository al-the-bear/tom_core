/// Demonstrates JSON serialization utilities including pretty printing
/// and JSON formatting for human-readable output.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXAMPLE 1: Basic Pretty Printing
// =============================================================================

class BasicPrettyPrintingExample {
  static String? compactJson;
  static String? prettyOutput;
  static bool isMultiLine = false;
  static bool containsName = false;
  static bool containsVersion = false;

  static void example1BasicPrettyPrinting() {
    compactJson = '{"name":"MyApp","version":"1.0.0","enabled":true}';
    prettyOutput = prettyJson(compactJson!);

    isMultiLine = prettyOutput!.split('\n').length > 1;
    containsName = prettyOutput!.contains('"name": "MyApp"');
    containsVersion = prettyOutput!.contains('"version": "1.0.0"');

    assert(isMultiLine, 'Pretty output should be multi-line');
    assert(containsName, 'Should contain name field');
    assert(containsVersion, 'Should contain version field');
  }
}

// =============================================================================
// EXAMPLE 2: Nested JSON Structures
// =============================================================================

class NestedJsonExample {
  static String? nestedJson;
  static String? prettyNested;
  static bool containsHost = false;
  static bool containsPoolSize = false;
  static bool containsEnabled = false;

  static void example2NestedJsonStructures() {
    nestedJson =
        '{"database":{"host":"localhost","port":5432,"settings":{"pool_size":10,"timeout":30}},"cache":{"enabled":true}}';
    prettyNested = prettyJson(nestedJson!);

    containsHost = prettyNested!.contains('"host": "localhost"');
    containsPoolSize = prettyNested!.contains('"pool_size": 10');
    containsEnabled = prettyNested!.contains('"enabled": true');

    assert(containsHost, 'Should contain host field');
    assert(containsPoolSize, 'Should contain pool_size field');
    assert(containsEnabled, 'Should contain enabled field');
  }
}

// =============================================================================
// EXAMPLE 3: JSON with Arrays
// =============================================================================

class JsonArraysExample {
  static String? arrayJson;
  static String? prettyArray;
  static bool containsAuth = false;
  static bool containsLogging = false;
  static bool containsPrimary = false;

  static void example3JsonWithArrays() {
    arrayJson =
        '{"features":["auth","logging","metrics"],"servers":[{"name":"primary","port":8080},{"name":"backup","port":8081}]}';
    prettyArray = prettyJson(arrayJson!);

    containsAuth = prettyArray!.contains('"auth"');
    containsLogging = prettyArray!.contains('"logging"');
    containsPrimary = prettyArray!.contains('"primary"');

    assert(containsAuth, 'Should contain auth feature');
    assert(containsLogging, 'Should contain logging feature');
    assert(containsPrimary, 'Should contain primary server');
  }
}

// =============================================================================
// EXAMPLE 4: Single-Line Pretty Format
// =============================================================================

class SingleLinePrettyExample {
  static String? simpleJson;
  static String? oneLineOutput;
  static bool containsSpaces = false;
  static bool hasNoNewlines = false;

  static void example4SingleLinePretty() {
    simpleJson = '{"a":1,"b":2,"c":3}';
    oneLineOutput = prettyJsonLine(simpleJson!);

    containsSpaces = oneLineOutput!.contains('"a": 1');
    hasNoNewlines = !oneLineOutput!.contains('\n');

    assert(containsSpaces, 'Single line should have spaces after colons');
    assert(hasNoNewlines, 'Single line should have no newlines');
  }
}

// =============================================================================
// EXAMPLE 5: Complex Single-Line Format
// =============================================================================

class ComplexSingleLineExample {
  static String? complexJson;
  static String? oneLineComplex;
  static bool containsId = false;
  static bool containsName = false;
  static bool hasNoNewlines = false;

  static void example5ComplexSingleLine() {
    complexJson = '{"user":{"id":123,"name":"Alice"},"active":true}';
    oneLineComplex = prettyJsonLine(complexJson!);

    containsId = oneLineComplex!.contains('"id": 123');
    containsName = oneLineComplex!.contains('"name": "Alice"');
    hasNoNewlines = !oneLineComplex!.contains('\n');

    assert(containsId, 'Should contain id field');
    assert(containsName, 'Should contain name field');
    assert(hasNoNewlines, 'Complex single line should have no newlines');
  }
}

// =============================================================================
// EXAMPLE 6: Using the Indent Encoder Directly
// =============================================================================

class IndentEncoderExample {
  static Map<String, dynamic>? dartMap;
  static String? encodedFromMap;
  static bool containsApplication = false;
  static bool containsModules = false;
  static bool containsDebug = false;

  static void example6IndentEncoder() {
    dartMap = {
      'application': 'tom_core',
      'modules': ['json', 'crypto', 'timezoned'],
      'config': {'debug': false, 'logLevel': 'info'},
    };
    encodedFromMap = indentEncoder.convert(dartMap!);

    containsApplication = encodedFromMap!.contains('"application": "tom_core"');
    containsModules = encodedFromMap!.contains('"json"');
    containsDebug = encodedFromMap!.contains('"debug": false');

    assert(containsApplication, 'Should contain application field');
    assert(containsModules, 'Should contain modules');
    assert(containsDebug, 'Should contain debug field');
  }
}

// =============================================================================
// EXAMPLE 7: Round-trip JSON formatting
// =============================================================================

class RoundTripExample {
  static String? originalCompact;
  static String? prettified;
  static String? compactAgain;
  static bool roundTripPreservesData = false;

  static void example7RoundTrip() {
    originalCompact = '{"key":"value","number":42}';
    prettified = prettyJson(originalCompact!);
    compactAgain = prettyJsonLine(prettified!);

    // Compact version should contain the same data
    roundTripPreservesData =
        compactAgain!.contains('"key": "value"') &&
        compactAgain!.contains('"number": 42');

    assert(roundTripPreservesData, 'Round-trip should preserve data');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  BasicPrettyPrintingExample.example1BasicPrettyPrinting();
  NestedJsonExample.example2NestedJsonStructures();
  JsonArraysExample.example3JsonWithArrays();
  SingleLinePrettyExample.example4SingleLinePretty();
  ComplexSingleLineExample.example5ComplexSingleLine();
  IndentEncoderExample.example6IndentEncoder();
  RoundTripExample.example7RoundTrip();
}

void main() => run();
