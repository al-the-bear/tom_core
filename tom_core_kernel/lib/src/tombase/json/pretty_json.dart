/// Utilities for formatting JSON strings for human readability.
///
/// This module provides simple functions to convert compact JSON strings
/// into nicely indented, readable formats. Useful for:
/// - Logging and debugging JSON data
/// - Displaying configuration files
/// - API response inspection
///
/// ## Example
/// ```dart
/// final compact = '{"name":"App","config":{"port":8080}}';
/// print(prettyJson(compact));
/// // Output:
/// // {
/// //   "name": "App",
/// //   "config": {
/// //     "port": 8080
/// //   }
/// // }
/// ```
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:convert';

// =============================================================================
// Formatters
// =============================================================================

/// JSON encoder configured with 2-space indentation for pretty printing.
///
/// Reusable encoder instance to avoid creating new encoders repeatedly.
final JsonEncoder indentEncoder = JsonEncoder.withIndent("  ");

/// Converts a compact JSON string into a pretty-printed, indented format.
///
/// Parses the input [json] string and re-encodes it with proper indentation
/// (2 spaces per level) and line breaks for readability.
///
/// ## Parameters
/// - [json]: A valid JSON string to format
///
/// ## Returns
/// A multi-line string with the JSON formatted for human readability.
///
/// ## Throws
/// - [FormatException] if [json] is not valid JSON
///
/// ## Example
/// ```dart
/// final formatted = prettyJson('{"a":1,"b":{"c":2}}');
/// // Returns:
/// // {
/// //   "a": 1,
/// //   "b": {
/// //     "c": 2
/// //   }
/// // }
/// ```
String prettyJson(String json) {
  var jsonMap = jsonDecode(json);
  return indentEncoder.convert(jsonMap);
}

/// Converts a compact JSON string into a single-line pretty format.
///
/// Similar to [prettyJson], but collapses the output into a single line
/// by replacing newlines with spaces. Useful for logging where multi-line
/// output is not desired but some formatting is still helpful.
///
/// ## Parameters
/// - [json]: A valid JSON string to format
///
/// ## Returns
/// A single-line string with formatted JSON (newlines replaced by spaces).
///
/// ## Example
/// ```dart
/// final oneLine = prettyJsonLine('{"a":1,"b":2}');
/// // Returns: '{ "a": 1, "b": 2 }'
/// ```
String prettyJsonLine(String json) {
  return prettyJson(json).split('\n').join(' ');
}
