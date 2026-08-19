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
///
/// That is a property of the codec, not of the calling convention.
/// [TomUserPreferenceCodec.decode] takes the whole [TomUserPreferenceDto]
/// because the check needs the stored type name alongside the text, and there
/// is deliberately no public sibling that takes the text alone: a guarantee
/// with an unguarded way around it holds only for the callers who happen to
/// pick the guarded method.
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
  /// [validateEncoded] and [decode] instead of being read as the reading
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
  /// A scalar's own type name, or — for anything else — the name the reflection
  /// registry holds for the value's class. The scalar cases are tested first,
  /// so an `int` never reaches reflection.
  ///
  /// Throws `preferences.type.not_reflected` when the registry does not know
  /// the class. That is the point rather than a limitation: the name written
  /// here is read back by another release on another platform, and a name the
  /// registry cannot produce is one no reader can ask for. See
  /// [typeNameForType] for why the registry is the identity.
  ///
  /// This is a question about the *value*, so the answer is its runtime class
  /// — which is not always the type a caller would write down for it. See
  /// [typeNameForType] for the two shapes where the two methods part company.
  ///
  /// [key] only names the preference in that exception, and is optional because
  /// a caller may ask for a value's stored name before it has decided where to
  /// put it.
  static String typeNameOf(Object value, [String key = '']) {
    if (value is String) return stringType;
    if (value is int) return intType;
    if (value is double) return doubleType;
    if (value is bool) return boolType;
    if (value is DateTime) return dateTimeType;
    return _reflectedClassOf(value, key).simpleName;
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
      valueType: typeNameOf(value, key),
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
  ///
  /// This writes the *text*; it does not ask what the value is stored under.
  /// So an unreflected object reaches `preferences.encode.failed` here, while
  /// the same object given to [encode] is refused one step earlier, by
  /// [typeNameOf], as `preferences.type.not_reflected` — a value with no
  /// durable name has nothing to be written under, whatever its text.
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

  /// Decodes [dto] as a [T] — the only way in to a stored preference value.
  ///
  /// Throws a [TomUserPreferenceCodecException] when the stored
  /// [TomUserPreferenceDto.valueType] is not the one [T] is stored under — the
  /// mismatch is reported rather than coerced, because a preference read as the
  /// wrong type is a value the caller will act on believing it is the user's.
  /// The whole DTO is required rather than just its text because that check
  /// needs the stored type name; a caller holding only the text should say what
  /// it believes the text to be, by building the DTO, rather than be given a
  /// way to skip saying it.
  ///
  /// A `DateTime` comes back in UTC, and only if the stored text names its own
  /// zone — see [parseInstant] for why a zoneless one is refused rather than
  /// localised. An `int` widens to a `double` when [T] asks for one.
  ///
  /// **A reflected [T] is rebuilt member by member.** A JSON member the class
  /// does not declare is ignored, and a member the class declares but the
  /// payload omits keeps its declared default. The `valueType` comparison is
  /// what makes that safe: a caller asking for the wrong class is refused
  /// before a single member is assigned.
  ///
  /// What no read can catch is a stored *row* whose `valueType` and text
  /// disagree, because a JSON object is shaped like every reflected class at
  /// once and nothing in the payload says which one wrote it. Such a row
  /// decodes to a fully-defaulted instance. [validateEncoded] does not close
  /// that gap either, and says why it does not try.
  static T decode<T extends Object>(TomUserPreferenceDto dto) {
    final identity = _identityOf(T, dto.key);
    if (dto.valueType != identity.name) {
      throw TomUserPreferenceCodecException(
        'preferences.decode.type_mismatch',
        "Preference '${dto.key}' was stored as ${dto.valueType} but was read "
            'as ${identity.name}.',
        parameters: {
          'key': dto.key,
          'stored': dto.valueType,
          'requested': identity.name,
        },
      );
    }
    return _decodeValue<T>(dto.value, dto.key, identity.reflectedClass);
  }

  /// The [TomUserPreferenceDto.valueType] a value of type [type] is stored
  /// under.
  ///
  /// A scalar is named by itself; anything else is named by the reflection
  /// registry, and throws `preferences.type.not_reflected` if the registry does
  /// not know it. [key] only names the preference in that exception.
  ///
  /// **Why the registry and not the type.** `Type.toString()` is the
  /// compiler's rendering, and this name is written into a database column,
  /// sent across the wire and read back by another release on another
  /// platform. That rendering is not durable enough for the job: it is not
  /// preserved by web minification, it carries the generic instantiation (so
  /// one class reached from two call sites can produce two names), and for an
  /// SDK type it can be a private name — `<String, int>{}` renders as `_Map`,
  /// which no caller can write and therefore no caller can read back. The
  /// registry name is a literal the generator emits, so it survives all three.
  ///
  /// It is the same registry [decode] resolves its type argument through,
  /// which is what makes the two halves symmetric: a value can be written
  /// under a name exactly when it can be read back under it.
  ///
  /// **Where this and [typeNameOf] diverge.** They answer different questions
  /// — [typeNameOf] names the class a *value* turned out to have, this names
  /// the class a *type* denotes. For a value stored under the class it is
  /// declared as those are the same string, which is what makes the two cases
  /// below easy to miss:
  ///
  /// * A **subclass** value is named by its own class rather than by the
  ///   supertype the caller declared, so a row written from a `Sub` is refused
  ///   by `decode<Base>` as `preferences.decode.type_mismatch`. That is the
  ///   intended strictness rather than a gap: reading it as the supertype
  ///   would silently drop the members only the subclass declares. Store a
  ///   preference under the class it is declared as.
  /// * An **instantiated generic** `Type` has no entry of its own, because the
  ///   registry is keyed by declaration: it holds `BoxPreference` and not
  ///   `BoxPreference<int>`. [typeNameOf] gets past that by resolving from the
  ///   instance, but a bare `Type` offers no route back to the declaration, so
  ///   `typeNameForType(BoxPreference<int>)` throws where
  ///   `typeNameForType(BoxPreference)` answers. Read a generic preference
  ///   under its bare class literal — the instantiation is deliberately not
  ///   part of the stored identity, and so is not restored by the read.
  static String typeNameForType(Type type, [String key = '']) =>
      _identityOf(type, key).name;

  /// The stored identity of [type]: the name it is written under and, for a
  /// non-scalar, the registry entry that name came from.
  ///
  /// Returning the mirror alongside the name is what lets [decode] resolve the
  /// class once and hand it to [_decodeValue], rather than each half asking the
  /// registry the same question and having to agree about the answer.
  static ({String name, ClassMirror? reflectedClass}) _identityOf(
    Type type,
    String key,
  ) {
    if (type == String) return (name: stringType, reflectedClass: null);
    if (type == int) return (name: intType, reflectedClass: null);
    if (type == double) return (name: doubleType, reflectedClass: null);
    if (type == bool) return (name: boolType, reflectedClass: null);
    if (type == DateTime) return (name: dateTimeType, reflectedClass: null);
    final mirror = _reflectedClass(type, key);
    return (name: mirror.simpleName, reflectedClass: mirror);
  }

  /// The registry entry for [type], or `preferences.type.not_reflected`.
  static ClassMirror _reflectedClass(Type type, String key) {
    final TypeMirror mirror;
    try {
      mirror = tomReflector.reflectType(type);
    } catch (error, stack) {
      throw _noStoredIdentity(type, key, error, stack);
    }
    if (mirror is! ClassMirror) throw _noStoredIdentity(type, key, null, null);
    return mirror;
  }

  /// The registry entry for [value]'s class, or
  /// `preferences.type.not_reflected`.
  ///
  /// Resolved from the *instance* rather than from `value.runtimeType`, because
  /// the registry is keyed by declaration and a generic value's runtime type is
  /// an instantiation: `reflectType(BoxPreference<int>)` finds nothing, while
  /// the instance lookup finds `BoxPreference` and names it that. The
  /// instantiation is deliberately not part of the stored name — a class
  /// written from two call sites at two instantiations is one preference type,
  /// and must come back under one name.
  static ClassMirror _reflectedClassOf(Object value, String key) {
    try {
      return tomReflector.reflect(value).type;
    } catch (error, stack) {
      throw _noStoredIdentity(value.runtimeType, key, error, stack);
    }
  }

  static TomUserPreferenceCodecException _noStoredIdentity(
    Type type,
    String key,
    Object? error,
    StackTrace? stack,
  ) {
    final subject = key.isEmpty ? 'A preference value' : "Preference '$key'";
    return TomUserPreferenceCodecException(
      'preferences.type.not_reflected',
      '$subject is a $type, which the reflection registry does not know, so '
          'there is no name it can be stored under and read back by. '
          'Reflected preference values must be annotated with @tomReflector.',
      parameters: {'key': key, 'valueType': type.toString()},
      rootException: error,
      stack: stack,
    );
  }

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

  /// Narrows the JSON text [json] to a [T]; [key] only names the preference in
  /// an error.
  ///
  /// [reflectedClass] is the registry entry [decode] already resolved [T] to,
  /// or `null` when [T] is a scalar. It is passed rather than looked up again
  /// because [decode] cannot have compared the stored name without resolving
  /// it, and a second lookup could only either repeat that work or disagree
  /// with it.
  ///
  /// Private, and deliberately so. Given the text alone there is nothing to
  /// contradict the caller's [T]: a stored `DateTime` read as a `String`
  /// succeeds here, because `"2026-03-04T05:06:07Z"` *is* a string. Only the
  /// stored [TomUserPreferenceDto.valueType] says otherwise, so [decode]
  /// compares it first and is the sole caller.
  static T _decodeValue<T extends Object>(
    String json,
    String key,
    ClassMirror? reflectedClass,
  ) {
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
    if (reflectedClass != null && raw is Map<String, Object?>) {
      final instance = tomReflectionInfo.createInstanceFromJson<T>(
        reflectedClass,
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
