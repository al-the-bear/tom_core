/// Encoding and decoding preference values with [TomUserPreferenceCodec].
///
/// A preference is a *typed* value that has to survive a JSON text column, so
/// every example below is really the same question asked of a different type:
/// what was stored, and does reading it back give the same value — with the
/// same type?
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// =============================================================================
// A reflected preference value
// =============================================================================

/// A structured preference — the shape a preference takes when it is a set of
/// related choices rather than a single scalar.
///
/// Declared here, in the sample, because the sample tree is one reflection
/// domain: the generator sweeps it into a single registry, which
/// `bootstrapSamples()` installs. Declaring the class in a sample file is what
/// makes it reflectable, and it is why this file's `main()` bootstraps before
/// it runs anything.
///
/// The codec resolves a reflected type through `tomReflector.reflectType`, so a
/// class the generator has not captured is refused at the *write*: a value
/// whose type the registry cannot name has no name to be stored under, and
/// inventing one would write a row nothing could read back. Example 7b is that
/// refusal, on a class left unannotated for it.
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

/// An enum preference — a choice from a closed set, which is the other shape a
/// non-scalar preference takes.
///
/// Annotated for the same reason [DisplayPreference] is, and it is the same
/// rule rather than a second one: the registry is what gives the type a name
/// that survives minification, and on the way back it is also what supplies the
/// constants to match the stored name against. An unannotated enum is refused
/// at the write, where the message can still say what to do about it.
@tomReflector
enum SortOrderPreference { ascending, descending }

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
  static String storedText = '';
  static bool sameMoment = false;

  static void example3DateTimeRoundTrip() {
    // A preference follows the user across devices, so an instant that carried
    // one device's local offset would come back meaning a different moment on
    // the next. The codec normalises to UTC on the way in and on the way out.
    final local = DateTime.utc(2026, 3, 4, 5, 6, 7).toLocal();
    final stored = TomUserPreferenceCodec.encode('ui.lastSeen', local);

    decoded = TomUserPreferenceCodec.decode<DateTime>(stored);
    storedText = stored.value;
    sameMoment = decoded!.isAtSameMomentAs(local);

    assert(
      stored.valueType == TomUserPreferenceCodec.dateTimeType,
      'Type name',
    );
    // What is asserted is the *stored text*, not `decoded.isUtc`. The flag only
    // says a conversion happened; it says nothing about which zone was
    // converted *from*, so it is true even of a value read wrongly. The `Z` in
    // the stored text is the thing that makes the instant unambiguous.
    assert(storedText.endsWith('Z"'), 'The stored text names its zone');
    assert(sameMoment, 'The moment survives the round-trip');
  }
}

// =============================================================================
// EXAMPLE 3b: A timestamp that names no zone is refused, not guessed
// =============================================================================

class ZonelessTimestampExample {
  static bool writeRejected = false;
  static bool readRejected = false;
  static String errorKey = '';

  static void example3bZonelessTimestamp() {
    // Nothing forces a client to use `encodeValue` — a hand-built write
    // request, or any non-Dart client, can put its own text on the wire.
    // `2026-03-04T05:06:07` is well-formed and completely ambiguous: it is a
    // wall-clock reading, and which instant it denotes depends on who reads it.
    const zoneless = '"2026-03-04T05:06:07"';

    try {
      TomUserPreferenceCodec.validateEncoded(
        TomUserPreferenceCodec.dateTimeType,
        zoneless,
        key: 'ui.lastSeen',
      );
    } on TomUserPreferenceCodecException catch (error) {
      writeRejected = true;
      errorKey = error.key;
    }

    try {
      // And if such a value ever reached storage, the read refuses too rather
      // than silently answering with this device's interpretation. Reading
      // means handing over the whole row: the codec has no entry point taking
      // the text alone, because such an entry point would have nothing to
      // check the caller's requested type against.
      TomUserPreferenceCodec.decode<DateTime>(
        TomUserPreferenceDto(
          key: 'ui.lastSeen',
          valueType: TomUserPreferenceCodec.dateTimeType,
          value: zoneless,
        ),
      );
    } on TomUserPreferenceCodecException {
      readRejected = true;
    }

    // `parseInstant` is the same test, available to a client that wants to
    // check its own text before sending it.
    assert(
      TomUserPreferenceCodec.parseInstant('2026-03-04T05:06:07') == null,
      'A zoneless timestamp is not an instant',
    );
    assert(
      TomUserPreferenceCodec.parseInstant('2026-03-04T05:06:07Z') != null,
      'A zoned timestamp is',
    );
    assert(writeRejected, 'The boundary refuses an ambiguous timestamp');
    assert(errorKey == 'preferences.encoded.not_an_instant', 'Named error');
    assert(readRejected, 'So does the read');
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
// EXAMPLE 4b: An enum is stored by its name, never by its index
// =============================================================================

class EnumRoundTripExample {
  static SortOrderPreference? restored;
  static String valueType = '';
  static String storedText = '';
  static bool unknownConstantRejected = false;
  static String errorKey = '';

  static void example4bEnumRoundTrip() {
    final stored = TomUserPreferenceCodec.encode(
      'ui.sortOrder',
      SortOrderPreference.descending,
    );

    restored = TomUserPreferenceCodec.decode<SortOrderPreference>(stored);
    valueType = stored.valueType;
    storedText = stored.value;

    try {
      // What happens when the enum outlives the row. A release that renames or
      // drops a constant leaves stored names it no longer declares, and the
      // codec refuses them: falling back to the first constant would hand the
      // caller a setting the user never chose, indistinguishable from one they
      // did. The index would have been worse still — silent, and wrong for
      // *every* stored row the moment a constant is inserted.
      TomUserPreferenceCodec.decode<SortOrderPreference>(
        TomUserPreferenceDto(
          key: 'ui.sortOrder',
          valueType: 'SortOrderPreference',
          value: '{"name":"alphabetical"}',
        ),
      );
    } on TomUserPreferenceCodecException catch (error) {
      unknownConstantRejected = true;
      errorKey = error.key;
    }

    assert(valueType == 'SortOrderPreference', 'The enum name is the type');
    assert(restored == SortOrderPreference.descending, 'The constant survives');
    assert(storedText == '{"name":"descending"}', 'Stored by name, not index');
    assert(unknownConstantRejected, 'A constant the enum dropped is refused');
    assert(
      errorKey == 'preferences.decode.unknown_enum_constant',
      'The exception names what it could not place',
    );
  }
}

// =============================================================================
// EXAMPLE 4c: A collection of scalars is a value in its own right
// =============================================================================

class CollectionRoundTripExample {
  static String listType = '';
  static String listText = '';
  static List<String> restoredList = const [];
  static String mapType = '';
  static Map<String, int> restoredMap = const {};
  static bool zonelessElementRejected = false;
  static bool mixedListRefused = false;
  static String errorKey = '';

  static void example4cCollectionRoundTrip() {
    // A list of pinned items is one of the most ordinary preferences there is,
    // so it is a shape of its own rather than something to wrap in a class.
    // Note the stored text: no envelope. An array is JSON's own shape, and the
    // element type is already in the name, so a wrapper would only be a second
    // thing for a non-Dart client to know about.
    final pinned = TomUserPreferenceCodec.encode('ui.pinned', <String>[
      'inbox',
      'today',
    ]);

    listType = pinned.valueType;
    listText = pinned.value;
    restoredList = TomUserPreferenceCodec.decode<List<String>>(pinned);

    // The name is *composed* from the codec's own type constants, never
    // rendered from a `Type` — which is the whole reason this works. A map
    // literal's runtime class is the private `_Map`, a name no reader could
    // ever ask for; `Map<String, int>` is one every reader can.
    final counts = TomUserPreferenceCodec.encode('ui.counts', <String, int>{
      'inbox': 3,
    });

    mapType = counts.valueType;
    restoredMap = TomUserPreferenceCodec.decode<Map<String, int>>(counts);

    try {
      // And because the element type is in the name, the boundary can check
      // every element without reflecting anything — including the zone rule,
      // which a list of instants needs exactly as much as a single one does.
      // This is the one non-scalar shape `validateEncoded` verifies in full.
      TomUserPreferenceCodec.validateEncoded(
        'List<DateTime>',
        '["2026-03-04T05:06:07Z", "2026-03-04T05:06:07"]',
        key: 'ui.recent',
      );
    } on TomUserPreferenceCodecException {
      zonelessElementRejected = true;
    }

    try {
      // The restriction, stated where it is met. `List<Object>` has no element
      // type to put in a name, so there would be nothing to read it back by —
      // and the advice cannot be "annotate it", which is why this has an error
      // key of its own rather than borrowing the unreflected-class one.
      TomUserPreferenceCodec.encode('ui.mixed', <Object>['a', 1]);
    } on TomUserPreferenceCodecException catch (error) {
      mixedListRefused = true;
      errorKey = error.key;
    }

    assert(listType == 'List<String>', 'The element type is part of the name');
    assert(listText == '["inbox","today"]', 'A bare array, with no envelope');
    assert(restoredList.length == 2, 'The list comes back typed, not dynamic');
    assert(mapType == 'Map<String, int>', 'A map is named the same way');
    assert(restoredMap['inbox'] == 3, 'And read back as the map it was');
    assert(zonelessElementRejected, 'The zone rule reaches into a collection');
    assert(mixedListRefused, 'A mixed collection has no name to be stored by');
    assert(
      errorKey == 'preferences.type.unsupported_collection',
      'The refusal names the actual restriction',
    );
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
// EXAMPLE 7: A number JSON cannot represent is refused by the codec
// =============================================================================

class NonFiniteNumberExample {
  static bool nanRejected = false;
  static String errorKey = '';
  static Object? reportedType;

  static void example7NonFiniteNumber() {
    // A NaN is not exotic for a preference: it is what a computed UI scale
    // produces when the number it divided by turned out to be zero. JSON has
    // no NaN and no Infinity, so there is nothing to store.
    final scale = 0.0 / 0.0;

    try {
      TomUserPreferenceCodec.encode('ui.scale', scale);
    } on TomUserPreferenceCodecException catch (error) {
      // The failure arrives as the one exception the whole module tells
      // callers to catch, and it names the preference that could not be
      // written — not just the line that could not write it.
      nanRejected = true;
      errorKey = error.key;
      reportedType = error.parameters?['valueType'];
    }

    assert(nanRejected, 'A non-finite double is refused');
    assert(errorKey == 'preferences.encode.not_json', 'The exception is named');
    assert(reportedType == 'double', 'The offending type is reported');
  }
}

// =============================================================================
// EXAMPLE 7b: A write refusal names the cause it detected
// =============================================================================

/// A class the generator has not captured — deliberately *not* annotated,
/// because it is the one case in which "add `@tomReflector`" is the right
/// advice, and the sample needs a value that earns it.
class UnnamedWindowState {
  /// The last window width, in logical pixels.
  int width = 800;
}

class RefusalCauseExample {
  static String topLevelCause = '';
  static String elementCause = '';
  static String mapKeyCause = '';
  static String elementTypeCause = '';
  static String setCause = '';
  static String unreflectedCause = '';
  static String setMessage = '';

  /// Encodes [value], which is expected to be refused, and answers the
  /// `cause` the refusal reported.
  static String _causeOf(Object value) {
    try {
      TomUserPreferenceCodec.encodeValue(value);
    } on TomUserPreferenceCodecException catch (error) {
      return error.parameters?['cause']?.toString() ?? '';
    }
    throw StateError('$value was expected to be refused');
  }

  static void example7bRefusalCauses() {
    // There are five ways to reach a write failure and they have five
    // different remedies. Only the last is fixed by annotating a class: a
    // Set and a Map<int, String> have no class of their own to annotate, and
    // a NaN is a number problem, not a shape problem.
    topLevelCause = _causeOf(double.nan);
    elementCause = _causeOf(<double>[1.0, double.infinity]);
    mapKeyCause = _causeOf(<int, String>{1: 'one'});
    elementTypeCause = _causeOf(<UnnamedWindowState>[UnnamedWindowState()]);
    setCause = _causeOf(<int>{1, 2});
    unreflectedCause = _causeOf(UnnamedWindowState());

    try {
      TomUserPreferenceCodec.encodeValue(<int>{1, 2});
    } on TomUserPreferenceCodecException catch (error) {
      setMessage = error.defaultUserMessage;
    }

    assert(topLevelCause == 'value_not_json', 'The NaN is the value itself');
    assert(elementCause == 'element_not_json', 'The Infinity is an element');
    assert(mapKeyCause == 'map_key_not_string', 'A JSON object keys by text');
    assert(elementTypeCause == 'element_not_scalar', 'Wrap the collection');
    assert(setCause == 'not_a_list_or_map', 'JSON has arrays, not sets');
    assert(unreflectedCause == 'unreflected_class', 'Annotate the class');

    // The Set is told to become a List, not to grow an annotation it has no
    // class of its own to carry.
    assert(setMessage.contains('toList()'), 'The remedy is in the sentence');
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
  ZonelessTimestampExample.example3bZonelessTimestamp();
  ReflectedRoundTripExample.example4ReflectedRoundTrip();
  EnumRoundTripExample.example4bEnumRoundTrip();
  CollectionRoundTripExample.example4cCollectionRoundTrip();
  TypeMismatchExample.example5TypeMismatch();
  ValidateEncodedExample.example6ValidateEncoded();
  NonFiniteNumberExample.example7NonFiniteNumber();
  RefusalCauseExample.example7bRefusalCauses();
}

void main() {
  bootstrapSamples();
  run();
}
