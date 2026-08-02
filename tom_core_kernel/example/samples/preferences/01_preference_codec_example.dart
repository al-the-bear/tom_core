/// Encoding and decoding preference values with [TomUserPreferenceCodec].
///
/// A preference is a *typed* value that has to survive a JSON text column, so
/// every example below is really the same question asked of a different type:
/// what was stored, and does reading it back give the same value — with the
/// same type?
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// A reflected preference value
// =============================================================================

/// A structured preference — the shape a preference takes when it is a set of
/// related choices rather than a single scalar.
///
/// Declared here, in the sample, because the codec resolves a reflected type
/// through `tomReflector.reflectType`: a class the generator has not captured
/// fails at the *decode*, not at the write. The sample tree is one reflection
/// domain seeded by `example/run_all_samples.dart`, so declaring it in a sample
/// file is what makes it reflectable.
///
/// The fields are plain and non-`final` because `createInstanceFromJson`
/// constructs a blank instance and assigns members — a `final` field would come
/// back at its default whatever was stored.
@tomReflector
class DisplayPreference {
  /// The theme the user picked.
  String theme = 'light';

  /// The UI font size in points.
  int fontSize = 14;

  /// Whether the compact layout is preferred.
  bool compact = false;
}

// =============================================================================
// EXAMPLE 1: Scalars carry their type alongside their JSON
// =============================================================================

class ScalarEncodingExample {
  static String stringType = '';
  static String intType = '';
  static String boolType = '';
  static String stringJson = '';
  static String intJson = '';

  static void example1ScalarEncoding() {
    // `typeNameOf` is what fills TomUserPreferenceDto.valueType. JSON forgets
    // types — `3` is an int and a double — so the name travels with the value.
    stringType = TomUserPreferenceCodec.typeNameOf('Europe/Berlin');
    intType = TomUserPreferenceCodec.typeNameOf(14);
    boolType = TomUserPreferenceCodec.typeNameOf(true);

    stringJson = TomUserPreferenceCodec.encodeValue('Europe/Berlin');
    intJson = TomUserPreferenceCodec.encodeValue(14);

    assert(stringType == TomUserPreferenceCodec.stringType, 'String type name');
    assert(intType == TomUserPreferenceCodec.intType, 'int type name');
    assert(boolType == TomUserPreferenceCodec.boolType, 'bool type name');
    assert(stringJson == '"Europe/Berlin"', 'String encodes as JSON text');
    assert(intJson == '14', 'int encodes as a JSON number');
  }
}

// =============================================================================
// EXAMPLE 2: Round-tripping a scalar through the DTO
// =============================================================================

class ScalarRoundTripExample {
  static String? timezone;
  static int? fontSize;
  static bool? compact;
  static double? scale;

  static void example2ScalarRoundTrip() {
    // `encode` builds the whole DTO — key, type name, JSON text — which is
    // exactly what the server stores and what the wire carries.
    final stored = TomUserPreferenceCodec.encode(
      TomUserPreferenceKeys.timezone,
      'Europe/Berlin',
    );

    timezone = TomUserPreferenceCodec.decode<String>(stored);
    fontSize = TomUserPreferenceCodec.decode<int>(
      TomUserPreferenceCodec.encode('ui.fontSize', 14),
    );
    compact = TomUserPreferenceCodec.decode<bool>(
      TomUserPreferenceCodec.encode('ui.compact', true),
    );
    scale = TomUserPreferenceCodec.decode<double>(
      TomUserPreferenceCodec.encode('ui.scale', 1.25),
    );

    assert(stored.key == TomUserPreferenceKeys.timezone, 'Key is carried');
    assert(timezone == 'Europe/Berlin', 'String round-trips');
    assert(fontSize == 14, 'int round-trips');
    assert(compact == true, 'bool round-trips');
    assert(scale == 1.25, 'double round-trips');
  }
}

// =============================================================================
// EXAMPLE 3: A DateTime preference is always UTC
// =============================================================================

class DateTimeRoundTripExample {
  static DateTime? decoded;
  static bool isUtc = false;
  static bool sameMoment = false;

  static void example3DateTimeRoundTrip() {
    // A preference follows the user across devices, so an instant that carried
    // one device's local offset would come back meaning a different moment on
    // the next. The codec normalises to UTC on the way in and on the way out.
    final local = DateTime.utc(2026, 3, 4, 5, 6, 7).toLocal();
    final stored = TomUserPreferenceCodec.encode('ui.lastSeen', local);

    decoded = TomUserPreferenceCodec.decode<DateTime>(stored);
    isUtc = decoded!.isUtc;
    sameMoment = decoded!.isAtSameMomentAs(local);

    assert(stored.valueType == TomUserPreferenceCodec.dateTimeType, 'Type name');
    assert(isUtc, 'A decoded DateTime is UTC-flagged');
    assert(sameMoment, 'The moment survives the round-trip');
  }
}

// =============================================================================
// EXAMPLE 4: A reflected object round-trips as an object
// =============================================================================

class ReflectedRoundTripExample {
  static String? theme;
  static int? fontSize;
  static bool? compact;
  static String valueType = '';
  static bool isDistinctInstance = false;

  static void example4ReflectedRoundTrip() {
    final original = DisplayPreference()
      ..theme = 'dark'
      ..fontSize = 18
      ..compact = true;

    final stored = TomUserPreferenceCodec.encode('ui.display', original);
    final restored = TomUserPreferenceCodec.decode<DisplayPreference>(stored);

    valueType = stored.valueType;
    theme = restored.theme;
    fontSize = restored.fontSize;
    compact = restored.compact;
    // Not the same instance: the value was genuinely serialized and rebuilt,
    // not passed through.
    isDistinctInstance = !identical(restored, original);

    assert(valueType == 'DisplayPreference', 'The class name is the type name');
    assert(theme == 'dark', 'Text member survives');
    assert(fontSize == 18, 'Numeric member survives');
    assert(compact == true, 'Boolean member survives');
    assert(isDistinctInstance, 'A new instance was constructed');
  }
}

// =============================================================================
// EXAMPLE 5: A mismatched read fails rather than coercing
// =============================================================================

class TypeMismatchExample {
  static bool mismatchRejected = false;
  static String errorKey = '';

  static void example5TypeMismatch() {
    final stored = TomUserPreferenceCodec.encode('ui.fontSize', 14);

    try {
      // Stored as an int, read as a String. Answering `"14"` would hand the
      // caller a value the user never chose, so the codec refuses.
      TomUserPreferenceCodec.decode<String>(stored);
    } on TomUserPreferenceCodecException catch (error) {
      mismatchRejected = true;
      errorKey = error.key;
    }

    assert(mismatchRejected, 'A type mismatch throws');
    assert(
      errorKey == 'preferences.decode.type_mismatch',
      'The exception names the mismatch',
    );
  }
}

// =============================================================================
// EXAMPLE 6: Validating a value that arrives already encoded
// =============================================================================

class ValidateEncodedExample {
  static bool matchingPairAccepted = false;
  static bool mismatchedPairRejected = false;
  static bool invalidJsonRejected = false;

  static void example6ValidateEncoded() {
    // A write request carries the value as text, so nothing has yet proved the
    // declared type and the text agree. Storing a disagreeing pair costs
    // nothing now and breaks every future read of the key — on every device.
    TomUserPreferenceCodec.validateEncoded(
      TomUserPreferenceCodec.intType,
      '14',
      key: 'ui.fontSize',
    );
    matchingPairAccepted = true;

    try {
      TomUserPreferenceCodec.validateEncoded(
        TomUserPreferenceCodec.intType,
        '"fourteen"',
        key: 'ui.fontSize',
      );
    } on TomUserPreferenceCodecException {
      mismatchedPairRejected = true;
    }

    try {
      TomUserPreferenceCodec.validateEncoded(
        TomUserPreferenceCodec.stringType,
        'not json at all',
        key: 'ui.theme',
      );
    } on TomUserPreferenceCodecException {
      invalidJsonRejected = true;
    }

    assert(matchingPairAccepted, 'A matching pair is accepted');
    assert(mismatchedPairRejected, 'A mismatched pair is rejected');
    assert(invalidJsonRejected, 'Invalid JSON is rejected');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

/// Runs every codec example in this file.
void run() {
  ScalarEncodingExample.example1ScalarEncoding();
  ScalarRoundTripExample.example2ScalarRoundTrip();
  DateTimeRoundTripExample.example3DateTimeRoundTrip();
  ReflectedRoundTripExample.example4ReflectedRoundTrip();
  TypeMismatchExample.example5TypeMismatch();
  ValidateEncodedExample.example6ValidateEncoded();
}

void main() => run();
