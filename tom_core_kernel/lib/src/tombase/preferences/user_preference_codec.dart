/// The value codec both halves of the preference contract use.
///
/// A preference is a *typed* value that has to survive a JSON column, so
/// something has to decide how an `int`, a `DateTime` and a reflected object
/// each become text and come back. That decision belongs to neither half alone:
/// the server writes with it and a client reads with it, and two encoders that
/// disagree by one convention (a local `DateTime`, an enum written as its
/// index) produce a preference that is stored successfully and read wrongly.
///
/// So it lives here, once, next to the DTO it fills.
///
/// ## What it will not do
///
/// It refuses a read whose stored [TomUserPreferenceDto.valueType] does not
/// match the type the caller asked for, rather than coercing. A preference that
/// was written as a `Duration` and is read as an `int` is a bug in the caller —
/// answering `3` (whatever that would mean) hides it, and the value the caller
/// then acts on is not the one the user chose.
library;

import 'dart:convert';

import 'package:tom_reflection/tom_reflection.dart';

import '../little_things/exception_base.dart';
import '../reflection/reflection.dart';
import 'user_preferences_contract.dart';

/// Raised when a preference cannot be encoded or decoded.
class TomUserPreferenceCodecException extends TomException {
  /// Creates the exception; parameters mirror [TomException].
  TomUserPreferenceCodecException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// Encodes and decodes preference values against [TomUserPreferenceDto].
///
/// Scalars are written as plain JSON; a reflected object goes through the same
/// reflection path the endpoint pipeline uses for every other DTO
/// ([TomReflectionInfo.convertToJsonString] /
/// [TomReflectionInfo.createInstanceFromJson]), so a preference object is
/// serialized exactly as it would be if it were an endpoint result.
class TomUserPreferenceCodec {
  const TomUserPreferenceCodec._();

  /// The [TomUserPreferenceDto.valueType] of a `String` value.
  static const String stringType = 'String';

  /// The [TomUserPreferenceDto.valueType] of an `int` value.
  static const String intType = 'int';

  /// The [TomUserPreferenceDto.valueType] of a `double` value.
  static const String doubleType = 'double';

  /// The [TomUserPreferenceDto.valueType] of a `bool` value.
  static const String boolType = 'bool';

  /// The [TomUserPreferenceDto.valueType] of a `DateTime` value.
  ///
  /// Always written in UTC: a preference follows the user across devices, and
  /// an instant that carried a device's local offset would come back meaning a
  /// different moment on the next one.
  ///
  /// The read path enforces the same rule rather than trusting the writer: a
  /// stored timestamp must name its zone, and one that does not is rejected by
  /// [validateEncoded] and [decodeValue] instead of being read as the reading
  /// device's local time. See [parseInstant].
  static const String dateTimeType = 'DateTime';

  /// The scalar type names, in the order [typeNameOf] tests them.
  static const List<String> scalarTypes = [
    stringType,
    intType,
    doubleType,
    boolType,
    dateTimeType,
  ];

  /// The [TomUserPreferenceDto.valueType] that [value] is stored under.
  ///
  /// A scalar's own type name, or a reflected object's runtime type name. The
  /// `num` cases are tested before the reflected fallback, so an `int` never
  /// reaches reflection.
  static String typeNameOf(Object value) {
    if (value is String) return stringType;
    if (value is int) return intType;
    if (value is double) return doubleType;
    if (value is bool) return boolType;
    if (value is DateTime) return dateTimeType;
    return value.runtimeType.toString();
  }

  /// Encodes [value] into the DTO stored under [key].
  ///
  /// [updatedAt] is the server's write timestamp; a client building a write
  /// request leaves it `null`, because when a preference was written is the
  /// server's answer.
  static TomUserPreferenceDto encode(
    String key,
    Object value, {
    DateTime? updatedAt,
  }) {
    return TomUserPreferenceDto(
      key: key,
      valueType: typeNameOf(value),
      value: encodeValue(value, key),
      updatedAt: updatedAt,
    );
  }

  /// Encodes [value] to its JSON text, without the surrounding DTO.
  ///
  /// [key] names the preference being written, and appears in the exception
  /// when the value cannot be encoded. It is optional because a caller may
  /// encode a value before it has decided where to put it.
  ///
  /// Every failure leaves here as a [TomUserPreferenceCodecException], which is
  /// the only exception the rest of the module tells callers to catch. That
  /// includes the scalar path: `jsonEncode` refuses a non-finite double, and
  /// `double.nan` is an ordinary outcome for a computed preference whose
  /// divisor turned out to be zero, not a programming error worth a different
  /// exception type.
  static String encodeValue(Object value, [String key = '']) {
    if (value is String || value is int || value is double || value is bool) {
      try {
        return jsonEncode(value);
      } catch (error, stack) {
        // JSON has no NaN and no Infinity, so there is nothing to write and
        // nothing to fall back on — a substitute would be a different value
        // read back as if it were the one stored.
        throw TomUserPreferenceCodecException(
          'preferences.encode.not_json',
          "Preference '$key' holds the ${value.runtimeType} value $value, "
              'which JSON cannot represent. Store a finite number, or a '
              'String naming the special case.',
          parameters: {
            'key': key,
            'valueType': value.runtimeType.toString(),
            'value': value.toString(),
          },
          rootException: error,
          stack: stack,
        );
      }
    }
    if (value is DateTime) {
      return jsonEncode(value.toUtc().toIso8601String());
    }
    try {
      return tomReflectionInfo.convertToJsonString(value);
    } catch (error, stack) {
      throw TomUserPreferenceCodecException(
        'preferences.encode.failed',
        "Preference '$key' holds a value of type ${value.runtimeType}, which "
            'could not be encoded. Reflected preference values must be '
            'annotated with @tomReflector.',
        parameters: {'key': key, 'valueType': value.runtimeType.toString()},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// Checks that [valueJson] is JSON and is shaped like a [valueType].
  ///
  /// For the boundary: a write request arrives with the value *already*
  /// encoded, so nothing on the way in has proved that the declared type and
  /// the text agree. Storing a disagreeing pair costs nothing now and fails
  /// every future read of that key — including reads on other devices, which is
  /// where it would be found.
  ///
  /// A non-scalar [valueType] is only required to be a JSON object. Which
  /// reflected class it names is deliberately not checked: a preference type
  /// may be one only the client knows, and a server that insisted on reflecting
  /// it would refuse to store values it is not meant to interpret.
  ///
  /// [key] only names the preference in an error.
  static void validateEncoded(
    String valueType,
    String valueJson, {
    String key = '',
  }) {
    final Object? raw;
    try {
      raw = jsonDecode(valueJson);
    } catch (error, stack) {
      throw TomUserPreferenceCodecException(
        'preferences.encoded.invalid_json',
        "Preference '$key' was written with a value that is not valid JSON.",
        parameters: {'key': key, 'valueType': valueType},
        rootException: error,
        stack: stack,
      );
    }
    final bool matches;
    switch (valueType) {
      case stringType:
        matches = raw is String;
      case intType:
        matches = raw is int;
      case doubleType:
        matches = raw is num;
      case boolType:
        matches = raw is bool;
      case dateTimeType:
        matches = raw is String && DateTime.tryParse(raw) != null;
      default:
        matches = raw is Map<String, Object?>;
    }
    if (!matches) {
      throw TomUserPreferenceCodecException(
        'preferences.encoded.type_mismatch',
        "Preference '$key' was written as $valueType but its value is not a "
            '$valueType.',
        parameters: {'key': key, 'valueType': valueType},
      );
    }
    // A timestamp can be well-formed and still ambiguous, so this is a second
    // question and not part of the type check above. Asking it here is the
    // whole point of the boundary: the text is stored once and read on devices
    // whose local zone nobody knows yet.
    if (valueType == dateTimeType &&
        raw is String &&
        parseInstant(raw) == null) {
      throw TomUserPreferenceCodecException(
        'preferences.encoded.not_an_instant',
        "Preference '$key' was written as a $dateTimeType whose text names no "
            'time zone, so it would be read as a different instant on every '
            'device. Write it in UTC (a trailing Z) or with an explicit '
            'offset.',
        parameters: {'key': key, 'valueType': valueType, 'value': raw},
      );
    }
  }

  /// Decodes [dto] as a [T].
  ///
  /// Throws a [TomUserPreferenceCodecException] when the stored
  /// [TomUserPreferenceDto.valueType] is not the one [T] is stored under — the
  /// mismatch is reported rather than coerced, because a preference read as the
  /// wrong type is a value the caller will act on believing it is the user's.
  static T decode<T extends Object>(TomUserPreferenceDto dto) {
    final expected = typeNameForType(T);
    if (dto.valueType != expected) {
      throw TomUserPreferenceCodecException(
        'preferences.decode.type_mismatch',
        "Preference '${dto.key}' was stored as ${dto.valueType} but was read "
            'as $expected.',
        parameters: {
          'key': dto.key,
          'stored': dto.valueType,
          'requested': expected,
        },
      );
    }
    return decodeValue<T>(dto.value, dto.key);
  }

  /// The [TomUserPreferenceDto.valueType] a value of type [type] is stored
  /// under.
  ///
  /// Derived from the type's own name, so it agrees with [typeNameOf] for every
  /// type either of them can see.
  static String typeNameForType(Type type) => type.toString();

  /// Parses [text] as a UTC instant, or returns `null` if it does not name one.
  ///
  /// Stricter than `DateTime.parse`, and deliberately so. `DateTime.parse`
  /// accepts a timestamp with no zone designator (`2026-03-04T05:06:07`, or a
  /// bare `2026-03-04`) and reads it as local time *in the reading process's
  /// zone* — so one stored string would mean a different instant on every
  /// device, which is precisely what [dateTimeType] promises cannot happen.
  ///
  /// The zone test is delegated to the SDK rather than written as a pattern:
  /// `DateTime.parse` returns a UTC-flagged value for exactly those strings
  /// that carry a designator — `Z`, `+HH:MM`, `+HHMM` or `+HH` — so
  /// [DateTime.isUtc] on the parse result *is* the answer, and there is no
  /// second, drifting copy of the ISO 8601 grammar to keep correct.
  ///
  /// Callers that build a write request themselves can use this to check their
  /// text before sending it, and get the same verdict the boundary will give.
  static DateTime? parseInstant(String text) {
    final parsed = DateTime.tryParse(text);
    if (parsed == null || !parsed.isUtc) return null;
    return parsed;
  }

  /// Decodes [json] as a [T]; [key] only names the preference in an error.
  ///
  /// A `DateTime` is returned in UTC and only if the stored text names its
  /// zone — see [parseInstant] for why a zoneless one is refused rather than
  /// localised.
  ///
  /// **A reflected [T] is rebuilt member by member, on the payload's terms.**
  /// A JSON member the class does not declare is ignored, and a member the
  /// class declares but the payload omits keeps its declared default. So a
  /// payload that belongs to a *different* reflected class decodes to a
  /// fully-defaulted instance rather than to an error.
  ///
  /// That is not an oversight, and it is not fixable here. A JSON object is
  /// shaped like every reflected class at once: nothing in the payload says
  /// which class wrote it, so this method has no evidence to test. A scalar is
  /// different — the decoded value carries its own type, which is why reading
  /// a stored `int` as a `String` throws here and reading one object's payload
  /// as another class does not.
  ///
  /// What identifies a stored object is its [TomUserPreferenceDto.valueType],
  /// and [decode] compares it against [T] before calling this. **Prefer
  /// [decode] for anything that came out of a store.** Reach for this method
  /// only when the type is already established by other means — an endpoint
  /// result whose shape the caller declared, say — because using it on a
  /// stored preference opts out of the one check that can catch the mistake.
  static T decodeValue<T extends Object>(String json, [String key = '']) {
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } catch (error, stack) {
      throw TomUserPreferenceCodecException(
        'preferences.decode.invalid_json',
        "Preference '$key' does not hold valid JSON.",
        parameters: {'key': key},
        rootException: error,
        stack: stack,
      );
    }
    if (raw is T) return raw;
    if (T == DateTime && raw is String) {
      final instant = parseInstant(raw);
      if (instant != null) return instant as T;
      final isTimestamp = DateTime.tryParse(raw) != null;
      throw TomUserPreferenceCodecException(
        isTimestamp
            ? 'preferences.decode.not_an_instant'
            : 'preferences.decode.type_mismatch',
        isTimestamp
            ? "Preference '$key' holds a timestamp that names no time zone, so "
                "reading it would have to invent one — this device's. That is "
                'an instant the writer did not necessarily mean, so it is '
                'refused instead.'
            : "Preference '$key' was read as a $dateTimeType but its text is "
                'not a timestamp.',
        parameters: {'key': key, 'requested': T.toString(), 'value': raw},
      );
    }
    if (T == double && raw is int) return raw.toDouble() as T;
    if (raw is Map<String, Object?>) {
      final TypeMirror typeMirror;
      try {
        typeMirror = tomReflector.reflectType(T);
      } catch (error, stack) {
        throw TomUserPreferenceCodecException(
          'preferences.decode.not_reflected',
          "Preference '$key' holds an object but $T is not reflected. "
              'Reflected preference values must be annotated with '
              '@tomReflector.',
          parameters: {'key': key, 'requested': T.toString()},
          rootException: error,
          stack: stack,
        );
      }
      if (typeMirror is! ClassMirror) {
        throw TomUserPreferenceCodecException(
          'preferences.decode.not_reflected',
          "Preference '$key' holds an object but $T is not a reflected class.",
          parameters: {'key': key, 'requested': T.toString()},
        );
      }
      final instance = tomReflectionInfo.createInstanceFromJson<T>(
        typeMirror,
        raw,
      );
      if (instance == null) {
        throw TomUserPreferenceCodecException(
          'preferences.decode.failed',
          "Preference '$key' could not be instantiated as $T.",
          parameters: {'key': key, 'requested': T.toString()},
        );
      }
      return instance;
    }
    throw TomUserPreferenceCodecException(
      'preferences.decode.failed',
      "Preference '$key' could not be decoded as $T.",
      parameters: {'key': key, 'requested': T.toString()},
    );
  }
}
