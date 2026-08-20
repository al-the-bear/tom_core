/// Demonstrates the null-returning and object accessors on
/// [TomTextResourceProvider].
///
/// This example covers:
/// - `getTextOrNull` — returns `null` for a missing key (vs `getText`, which
///   echoes the key back as a development-time fallback)
/// - `getObject` / `getObjectOrNull` — retrieve non-String values (ints, bools,
///   nested maps) with key-echo vs `null` fallback respectively
/// - `existsObject` — whether *any* value (not just a String) exists at a path
///
/// The pair of accessors lets callers choose their missing-key behaviour:
/// `getText`/`getObject` surface the key itself so missing resources are
/// obvious on screen, while the `OrNull` variants are for code that wants to
/// branch on presence.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

void run() {
  print('=== 03: Resource Fallback Example ===\n');

  final resources = TomTextResourceProvider.from({
    'app': {
      'title': 'Checkout',
      'retries': 3, // non-String value
      'beta': true, // non-String value
      'limits': {'max': 50}, // nested map
    },
  });

  // ===========================================================================
  // Example 1: getTextOrNull returns null for a missing key
  // ===========================================================================

  print('1. getText vs getTextOrNull on a missing key:');

  final presentText = resources.getTextOrNull('app.title');
  final missingOrNull = resources.getTextOrNull('app.subtitle');
  final missingEcho = resources.getText('app.subtitle'); // echoes the key

  print('   getTextOrNull("app.title"): $presentText');
  print('   getTextOrNull("app.subtitle"): $missingOrNull');
  print('   getText("app.subtitle"): "$missingEcho" (key echoed back)');
  print('');

  // ===========================================================================
  // Example 2: getTextOrNull returns null for a non-String value
  // ===========================================================================

  print('2. getTextOrNull only returns Strings:');

  // `retries` exists but is an int, so the text accessor reports it absent.
  final retriesAsText = resources.getTextOrNull('app.retries');

  print('   getTextOrNull("app.retries") (value is int): $retriesAsText');
  print('');

  // ===========================================================================
  // Example 3: getObject / getObjectOrNull retrieve non-String values
  // ===========================================================================

  print('3. Object accessors return values of any type:');

  final retries = resources.getObject('app.retries');
  final beta = resources.getObjectOrNull('app.beta');
  final limits = resources.getObjectOrNull('app.limits');
  final missingObject = resources.getObjectOrNull('app.missing');
  final missingObjectEcho = resources.getObject(
    'app.missing',
  ); // echoes the key

  print('   getObject("app.retries"): $retries');
  print('   getObjectOrNull("app.beta"): $beta');
  print('   getObjectOrNull("app.limits"): $limits');
  print('   getObjectOrNull("app.missing"): $missingObject');
  print('   getObject("app.missing"): "$missingObjectEcho" (key echoed back)');
  print('');

  // ===========================================================================
  // Example 4: existsObject checks for any value, exists only for Strings
  // ===========================================================================

  print('4. existsObject vs exists:');

  final retriesExistsObject = resources.existsObject('app.retries');
  final retriesExistsText = resources.exists(
    'app.retries',
  ); // int → not a String
  final titleExistsText = resources.exists('app.title');
  final missingExistsObject = resources.existsObject('app.missing');

  print('   existsObject("app.retries"): $retriesExistsObject');
  print('   exists("app.retries") (int, not String): $retriesExistsText');
  print('   exists("app.title"): $titleExistsText');
  print('   existsObject("app.missing"): $missingExistsObject');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: text fallback behaviour
  assert(presentText == 'Checkout');
  assert(missingOrNull == null);
  assert(missingEcho == 'app.subtitle');

  // Example 2: non-String values are absent to the text accessor
  assert(retriesAsText == null);

  // Example 3: object accessors
  assert(retries == 3);
  assert(beta == true);
  assert(limits is Map && limits['max'] == 50);
  assert(missingObject == null);
  assert(missingObjectEcho == 'app.missing');

  // Example 4: existence checks
  assert(retriesExistsObject);
  assert(!retriesExistsText);
  assert(titleExistsText);
  assert(!missingExistsObject);
}

/// Standalone entry point.
void main() {
  requireAsserts();
  run();
}
