/// Demonstrates the JSON *serialization* contract: a value object that renders
/// itself with [TomJsonSerializable], and how [makeCleanJsonMap] meets it.
///
/// This example covers:
/// - Implementing TomJsonSerializable on an all-`final` value object
/// - Converting a serializable that is nested inside a plain map
/// - Converting serializables held in a list, at any depth
/// - Keeping a deliberate `null` while dropping values with no JSON form
/// - Handing the cleaned map to jsonEncode / prettyJson
///
/// Reflection is the default path for wire types, so this interface is the
/// escape hatch for the rest — a type that must match a wire shape it does not
/// own, or one whose fields are `final` and therefore unassignable after
/// construction, which is exactly what reflection would need to populate them.
///
/// Formatting the resulting JSON is `01_json_formatting_example.dart`;
/// sanitizing an arbitrary untyped map is example 6 of
/// `02_json_navigation_example.dart`.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/json/04_json_serialization_example.dart
/// ```
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// The value objects
// =============================================================================

/// An endpoint that renders itself to JSON.
///
/// Every field is `final`, which is what makes the interface the right tool
/// here: reflection cannot assign a `final` field, so a type that wants
/// immutability has to say how it serializes.
class ServiceEndpoint implements TomJsonSerializable {
  const ServiceEndpoint(this.name, this.url, this.enabled, {this.region});

  final String name;
  final String url;
  final bool enabled;

  /// Absent for a globally routed endpoint. Reported as an explicit `null`
  /// rather than omitted, so a consumer can tell "no region" from "the sender
  /// did not say".
  final String? region;

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    'enabled': enabled,
    'region': region,
  };
}

/// A service that owns endpoints, so its `toJson` nests serializables.
///
/// Note what it does *not* do: it does not call `toJson()` on its endpoints.
/// It leaves them as objects and lets [makeCleanJsonMap] convert them, which
/// is the behaviour example 2 below pins.
class ServiceDescriptor implements TomJsonSerializable {
  const ServiceDescriptor(this.id, this.primary, this.fallbacks);

  final String id;
  final ServiceEndpoint primary;
  final List<ServiceEndpoint> fallbacks;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'primary': primary,
    'fallbacks': fallbacks,
  };
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  print('=== 04: JSON Serialization Example ===\n');

  // ===========================================================================
  // Example 1: A value object renders itself
  // ===========================================================================

  print('1. TomJsonSerializable.toJson():');

  const authEndpoint = ServiceEndpoint(
    'auth',
    'https://api.example.com/auth',
    true,
    region: 'eu-central',
  );
  final authJson = authEndpoint.toJson();

  print('   - toJson():  $authJson');
  print('');

  // ===========================================================================
  // Example 2: makeCleanJsonMap converts serializables it meets
  // ===========================================================================

  print('2. Conversion of a nested serializable:');

  // `primary` is a ServiceEndpoint object, not a map. The sanitiser resolves
  // the interface with a type test and converts it, then cleans the result in
  // turn — so a value object can be left in place instead of every owner
  // having to remember to call toJson() on its children.
  const globalEndpoint = ServiceEndpoint(
    'global',
    'https://api.example.com/global',
    false,
  );
  const descriptor = ServiceDescriptor('billing', authEndpoint, [
    globalEndpoint,
  ]);

  final descriptorClean = makeCleanJsonMap(descriptor.toJson());
  final primaryClean = descriptorClean['primary'] as Map<String, Object?>;

  print('   - primary converted to a map: ${primaryClean['name']}');
  print(
    '   - primary is a Map now:       ${descriptorClean['primary'] is Map}',
  );
  print('');

  // ===========================================================================
  // Example 3: Serializables inside a list are converted too
  // ===========================================================================

  print('3. Conversion inside a list:');

  final fallbacksClean = descriptorClean['fallbacks'] as List;
  final firstFallback = fallbacksClean.first as Map<String, Object?>;

  print('   - fallbacks[0] name:  ${firstFallback['name']}');
  print('   - fallbacks[0] a Map: ${fallbacksClean.first is Map}');
  print('');

  // ===========================================================================
  // Example 4: A deliberate null survives; a value with no JSON form does not
  // ===========================================================================

  print('4. Null is kept, non-JSON values are dropped:');

  // `region` is null on globalEndpoint: absent region, stated explicitly.
  // `lastProbed` is a DateTime, which has no JSON form and is filtered out —
  // a type that wants to travel must say how, which is the whole point of the
  // interface.
  final probe = <String, Object?>{
    'endpoint': globalEndpoint,
    'lastProbed': DateTime.utc(2026, 1, 1),
    'note': null,
  };
  final probeClean = makeCleanJsonMap(probe);
  final endpointClean = probeClean['endpoint'] as Map<String, Object?>;

  print('   - note present:       ${probeClean.containsKey('note')}');
  print('   - lastProbed present: ${probeClean.containsKey('lastProbed')}');
  print('   - region present:     ${endpointClean.containsKey('region')}');
  print('   - region value:       ${endpointClean['region']}');
  print('');

  // ===========================================================================
  // Example 5: The cleaned map is ready to encode
  // ===========================================================================

  print('5. Encoding the cleaned map:');

  // makeCleanJsonMap prepares a map for jsonEncode and leaves the encoding to
  // the caller, so the two halves of the module meet here: sanitize, then
  // format with the helpers from example 01.
  final encoded = jsonEncode(descriptorClean);
  final formatted = prettyJsonLine(encoded);

  print('   - encoded:   ${encoded.substring(0, 40)}...');
  print('   - formatted: ${formatted.substring(0, 44)}...');
  print('');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: the object renders its own shape, nulls included.
  assert(authJson['name'] == 'auth');
  assert(authJson['enabled'] == true);
  assert(authJson['region'] == 'eu-central');
  assert(authJson.length == 4);

  // Example 2: a nested serializable became a map, cleaned in turn.
  assert(descriptorClean['id'] == 'billing');
  assert(descriptorClean['primary'] is Map);
  assert(primaryClean['name'] == 'auth');
  assert(primaryClean['url'] == 'https://api.example.com/auth');

  // Example 3: list elements were converted at their own depth.
  assert(descriptorClean['fallbacks'] is List);
  assert(fallbacksClean.length == 1);
  assert(fallbacksClean.first is Map);
  assert(firstFallback['name'] == 'global');
  assert(firstFallback['enabled'] == false);

  // Example 4: null is a JSON value and is kept; a DateTime is not and is not.
  assert(probeClean.containsKey('note'));
  assert(probeClean['note'] == null);
  assert(!probeClean.containsKey('lastProbed'));
  assert(endpointClean.containsKey('region'));
  assert(endpointClean['region'] == null);

  // Example 5: the cleaned map survives a real encode.
  assert(encoded.contains('"id":"billing"'));
  assert(encoded.contains('"name":"global"'));
  assert(formatted.contains('"id": "billing"'));
  assert(!formatted.contains('\n'));
}

void main() {
  prepareSampleProcess();
  run();
}
