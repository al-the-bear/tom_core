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
import 'user_preference_keys.dart';
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
/// ## What a preference value may be
///
/// Four shapes, and nothing else:
///
/// | Shape | Stored as | Named by |
/// | ----- | --------- | -------- |
/// | `String`, `int`, `double`, `bool` | plain JSON | itself |
/// | `DateTime` | an ISO 8601 instant in UTC | `DateTime` |
/// | a `List`/`Map<String,…>` of one scalar | array or object | `List<int>` |
/// | a `@tomReflector` **enum** | `{"name": "<constant>"}` | the registry |
/// | a `@tomReflector` **class** | a JSON object of members | the registry |
///
/// A value of any other shape is refused when it is named, by [typeNameOf].
/// That includes a collection that is not one of the ten supported ones — an
/// untyped `[]`, a mixed `List<Object>`, a `Map` keyed by anything but
/// `String`, a nested collection, a list of reflected objects: those raise
/// `preferences.type.unsupported_collection`, whose message names the actual
/// restriction rather than advising an annotation a `List<Object>` cannot
/// carry. Wrap such a value in a reflected class, whose members can then
/// evolve under a name that survives.
///
/// **Why collections are a shape of their own** rather than something to wrap.
/// The element type is *in* the stored name, so it survives the round-trip on
/// the same terms a scalar does — the name is composed from this class's own
/// constants, not from `Type.toString()`, which [typeNameForType] explains is
/// not durable enough to store. And because the name carries the element type,
/// [validateEncoded] can check every element of a stored row without
/// reflecting anything: a collection is the one non-scalar shape the boundary
/// verifies *completely*, which a reflected class is not.
///
/// The two reflected shapes share one rule — the value's class must carry
/// `@tomReflector` — so there is no separate thing to know about enums. What
/// the annotation buys is the same in both cases: a name that is a literal the
/// generator emitted rather than one the compiler is free to rewrite, and, for
/// an enum, the constants to match a stored name against on the way back.
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

  /// The five scalar shapes, in the order [typeNameOf] tests a value against
  /// them.
  ///
  /// The order is load-bearing, and `int` before `double` is the reason. On the
  /// web both are JS numbers and an integral `double` answers to `is int`, so
  /// the first row that matches decides the stored name; swapping the two would
  /// change what a whole platform writes. On the VM the types are disjoint and
  /// the order is free — which is exactly why it needs saying here, where the
  /// order is set, rather than being discovered by a reader who reshuffles the
  /// rows and sees every test still pass.
  ///
  /// Only the value tests are ordered. [_identityOf] matches a row by its
  /// [_ScalarKind.dartType], and `Type` equality is exact, so no row can shadow
  /// another there.
  ///
  /// `static final` rather than `const`, because a function literal is not a
  /// constant expression. That is the same trade [_collectionTypes] makes: a
  /// table that holds what the code does cannot drift from the code that does
  /// it, which is worth more than a constness nothing here asks for.
  ///
  /// Every question either side of the column asks about a scalar is answered
  /// from these rows — the Dart type, the stored name, the write-side and
  /// read-side shape tests, the narrowing back to a Dart value, and the two
  /// typed collection constructors. **A sixth scalar is one row**, which is the
  /// property this table exists for: the alternative had the write side reading
  /// the table while the read side re-listed the same five names in three
  /// switches, none of which failed to compile when a row was added — so a
  /// forgotten edit was a preference that stored and then could not be read.
  static final List<_ScalarKind> _scalars = [
    _ScalarKind(
      dartType: String,
      name: stringType,
      matchesValue: (v) => v is String,
      matchesJson: (j) => j is String,
      toJson: (v) => v,
      narrow: (raw, _, _) => raw is String ? raw : null,
      listType: List<String>,
      mapType: Map<String, String>,
      isListOf: (v) => v is List<String>,
      isMapOf: (v) => v is Map<String, String>,
      listFrom: List<String>.from,
      mapFrom: Map<String, String>.from,
    ),
    _ScalarKind(
      dartType: int,
      name: intType,
      matchesValue: (v) => v is int,
      matchesJson: (j) => j is int,
      toJson: (v) => v,
      narrow: (raw, _, _) => raw is int ? raw : null,
      listType: List<int>,
      mapType: Map<String, int>,
      isListOf: (v) => v is List<int>,
      isMapOf: (v) => v is Map<String, int>,
      listFrom: List<int>.from,
      mapFrom: Map<String, int>.from,
    ),
    // `num` and not `double` on the read side: JSON writes `1.0` as `1`, and a
    // row a non-Dart client wrote is integral even where the preference is not.
    // The narrowing is the second half of that admission: without it a row this
    // row admits at the boundary would fail to decode.
    _ScalarKind(
      dartType: double,
      name: doubleType,
      matchesValue: (v) => v is double,
      matchesJson: (j) => j is num,
      toJson: (v) => v,
      narrow: (raw, _, _) => raw is double
          ? raw
          : raw is int
          ? raw.toDouble()
          : null,
      listType: List<double>,
      mapType: Map<String, double>,
      isListOf: (v) => v is List<double>,
      isMapOf: (v) => v is Map<String, double>,
      listFrom: List<double>.from,
      mapFrom: Map<String, double>.from,
    ),
    _ScalarKind(
      dartType: bool,
      name: boolType,
      matchesValue: (v) => v is bool,
      matchesJson: (j) => j is bool,
      toJson: (v) => v,
      narrow: (raw, _, _) => raw is bool ? raw : null,
      listType: List<bool>,
      mapType: Map<String, bool>,
      isListOf: (v) => v is List<bool>,
      isMapOf: (v) => v is Map<String, bool>,
      listFrom: List<bool>.from,
      mapFrom: Map<String, bool>.from,
    ),
    _ScalarKind(
      dartType: DateTime,
      name: dateTimeType,
      matchesValue: (v) => v is DateTime,
      matchesJson: (j) => j is String && DateTime.tryParse(j) != null,
      toJson: (v) => (v as DateTime).toUtc().toIso8601String(),
      // A tear-off rather than a literal: this row's narrowing is the only one
      // with something to explain, and twenty lines of error text inside a
      // table literal would stop the table being readable as a table. See
      // [_narrowInstant].
      narrow: _narrowInstant,
      listType: List<DateTime>,
      mapType: Map<String, DateTime>,
      isListOf: (v) => v is List<DateTime>,
      isMapOf: (v) => v is Map<String, DateTime>,
      listFrom: List<DateTime>.from,
      mapFrom: Map<String, DateTime>.from,
    ),
  ];

  /// The first row [value] has the shape of, or `null` when it is not a
  /// scalar.
  ///
  /// *First*, and the order is the one [_scalars] documents: on the web an
  /// integral `double` answers to `is int`, so which row claims such a value
  /// is decided here and nowhere else.
  static _ScalarKind? _scalarOf(Object value) {
    for (final scalar in _scalars) {
      if (scalar.matchesValue(value)) return scalar;
    }
    return null;
  }

  /// The row named [scalarType], or `null` when no row claims that name.
  ///
  /// The one lookup by stored name, so that "which scalar is this" is answered
  /// from the table by every side of the column — the boundary check, the
  /// narrowing, and the collection rebuild — rather than by a `switch` each of
  /// them keeps in step by hand.
  ///
  /// `null` for an unclaimed name is load-bearing rather than defensive: it is
  /// how a `valueType` naming a reflected class reaches the object branch
  /// instead of being mistaken for an unrecognised scalar.
  static _ScalarKind? _scalarNamed(String scalarType) {
    for (final scalar in _scalars) {
      if (scalar.name == scalarType) return scalar;
    }
    return null;
  }

  /// The scalar type names, in the order [typeNameOf] tests them.
  ///
  /// A view of [_scalars] rather than a list of its own. The ordering above is
  /// therefore not a claim about this list that someone has to keep true; it is
  /// the only order there is, and [typeNameOf] and [validateEncoded] read the
  /// same rows this is projected from.
  static final List<String> scalarTypes = List.unmodifiable(
    _scalars.map((scalar) => scalar.name),
  );

  /// The [TomUserPreferenceDto.valueType] of a list whose elements are
  /// [element]s.
  ///
  /// Composed from this class's own constants rather than rendered from a
  /// `Type`, which is what makes a collection name as durable as a scalar one:
  /// there is no compiler rendering in it to be minified or to leak an
  /// instantiation. See [typeNameForType] for why that matters.
  static String _listTypeOf(String element) => 'List<$element>';

  /// The [TomUserPreferenceDto.valueType] of a map whose values are [element]s.
  ///
  /// The key is always [stringType], and is written into the name rather than
  /// left implicit: JSON object keys are strings, so any other key type would
  /// need an encoding convention — exactly the kind of silent convention this
  /// module exists to settle once. A `Map` keyed by anything else is refused.
  static String _mapTypeOf(String element) => 'Map<$stringType, $element>';

  /// The ten supported collection shapes, keyed by the `Type` a caller reads
  /// one back as.
  ///
  /// `static final` rather than `const`: the names are composed by
  /// [_listTypeOf] and [_mapTypeOf] so that the naming rule lives in one place
  /// and this table cannot drift from [_collectionParts], which parses it.
  static final Map<Type, String> _collectionTypes = {
    for (final scalar in _scalars) scalar.listType: _listTypeOf(scalar.name),
    for (final scalar in _scalars) scalar.mapType: _mapTypeOf(scalar.name),
  };

  /// The stored name of [value] if it is a supported collection, else `null`.
  ///
  /// An `is` test per row rather than a `runtimeType` lookup in
  /// [_collectionTypes], because a runtime class is not the declared one: a
  /// decoded list is a `JSArray` under dart2js and a map literal is a `_Map`,
  /// neither of which is `== List<String>`. `is` asks the question the table
  /// cannot — so the test lives in the row, as [_ScalarKind.isListOf].
  ///
  /// Every list is tried before any map, and the rows are tried in [_scalars]
  /// order within each, which is the order the hand-written chain this replaced
  /// had. The `int`-before-`double` reason applies here too.
  static String? _collectionNameOf(Object value) {
    for (final scalar in _scalars) {
      if (scalar.isListOf(value)) return _listTypeOf(scalar.name);
    }
    for (final scalar in _scalars) {
      if (scalar.isMapOf(value)) return _mapTypeOf(scalar.name);
    }
    return null;
  }

  /// Reads [valueType] back as the collection it names, or `null` if it names
  /// no collection.
  ///
  /// Matched against [_listTypeOf] and [_mapTypeOf] rather than parsed with a
  /// pattern, so the name this understands is by construction the name
  /// [typeNameOf] writes. A grammar written twice is a grammar that drifts.
  static ({bool isMap, String element})? _collectionParts(String valueType) {
    for (final element in scalarTypes) {
      if (valueType == _listTypeOf(element)) {
        return (isMap: false, element: element);
      }
      if (valueType == _mapTypeOf(element)) {
        return (isMap: true, element: element);
      }
    }
    return null;
  }

  /// The JSON member an enum value is stored in: its constant *name*.
  ///
  /// The name and not the index, which is the convention this module's own
  /// dartdoc names as worth settling centrally. An index is positional, so
  /// inserting a constant into the enum silently changes the meaning of every
  /// preference already stored — the user's saved choice becomes its
  /// neighbour's, on the next release, with nothing to notice it by. The name
  /// moves only when the constant is renamed, and a renamed constant is
  /// refused loudly rather than misread (see [decode]).
  static const String enumNameField = 'name';

  /// The [TomUserPreferenceDto.valueType] that [value] is stored under.
  ///
  /// A scalar's own type name, a supported collection's composed name, or —
  /// for anything else — the name the reflection registry holds for the value's
  /// class.
  ///
  /// Those three are consulted in that order, and only one of the two
  /// precedences decides an answer. The scalar table comes before the registry
  /// to keep a scalar's stored name in the same row as the predicates that
  /// produce and check it — not to change what it is named, because the
  /// registry knows all five core scalars and returns the same strings. Which
  /// is why no behavioural test can catch that half of the ordering, and why
  /// the agreement itself is asserted instead. The precedence that does decide
  /// an answer is collections before the registry, two paragraphs down.
  ///
  /// Throws `preferences.type.not_reflected` when the registry does not know
  /// the class. That is the point rather than a limitation: the name written
  /// here is read back by another release on another platform, and a name the
  /// registry cannot produce is one no reader can ask for. See
  /// [typeNameForType] for why the registry is the identity.
  ///
  /// A collection that is not one of the ten supported shapes throws
  /// `preferences.type.unsupported_collection` *here*, before reflection is
  /// asked about it. Reflection would answer for some of them — the registry
  /// knows `List` — and the value would then be stored under that name and
  /// silently encoded as `{}`, every element dropped. Refusing at the name is
  /// what turns that into an error the writer can read.
  ///
  /// This is a question about the *value*, so the answer is its runtime class
  /// — which is not always the type a caller would write down for it. See
  /// [typeNameForType] for the two shapes where the two methods part company.
  ///
  /// [key] only names the preference in that exception, and is optional because
  /// a caller may ask for a value's stored name before it has decided where to
  /// put it.
  static String typeNameOf(Object value, [String key = '']) {
    final scalar = _scalarOf(value);
    if (scalar != null) return scalar.name;
    final collection = _collectionNameOf(value);
    if (collection != null) return collection;
    if (value is Iterable || value is Map) {
      throw _unsupportedCollection(value.runtimeType, key);
    }
    return _reflectedClassOf(value, key).simpleName;
  }

  /// Encodes [value] into the DTO stored under [key].
  ///
  /// [updatedAt] is the server's write timestamp; a client building a write
  /// request leaves it `null`, because when a preference was written is the
  /// server's answer.
  ///
  /// Throws a [TomUserPreferenceKeyException] when [key] does not satisfy
  /// [TomUserPreferenceKeys]. This is the write path's first gate: a DTO is the
  /// *addressed* artifact, so a key that cannot be addressed must not reach one
  /// — the alternative is a value that encodes successfully and is then
  /// unstorable. Unlike [typeNameOf] and [encodeValue], whose key is optional
  /// and only names the preference in an exception, the key here is the
  /// preference's identity.
  static TomUserPreferenceDto encode(
    String key,
    Object value, {
    DateTime? updatedAt,
  }) {
    TomUserPreferenceKeys.validate(key);
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
  /// An enum is written as `{"name": "<constant>"}` — see [enumNameField] for
  /// why the name and not the index, and the class dartdoc for why an object
  /// and not a bare string.
  ///
  /// This writes the *text*; it does not ask what the value is stored under.
  /// So an unreflected object reaches `preferences.encode.failed` here, while
  /// the same object given to [encode] is refused one step earlier, by
  /// [typeNameOf], as `preferences.type.not_reflected` — a value with no
  /// durable name has nothing to be written under, whatever its text. An
  /// unreflected *enum* takes that same split: its text is writable here,
  /// since a constant name needs no registry, and it is [encode] that refuses
  /// it for having no name to be stored under. A mixed `List<Object>` takes it
  /// too — `["a",1]` is perfectly good JSON, so it is written here and refused
  /// by [typeNameOf] for naming no supported shape.
  ///
  /// A refusal names the cause it detected rather than a single generic one,
  /// and carries it as a `cause` parameter for a caller that has to branch:
  ///
  /// | `cause` | The value | The remedy |
  /// | ------- | --------- | ---------- |
  /// | `value_not_json` | a non-finite number | store a finite one |
  /// | `element_not_json` | a collection holding one | the same, one level on |
  /// | `map_key_not_string` | a `Map<int, …>` | key it by `String` |
  /// | `element_not_scalar` | a `List<Thing>` | wrap the whole collection |
  /// | `not_a_list_or_map` | a `Set`, a lazy `Iterable` | `toList()` it |
  /// | `unreflected_class` | an unannotated class | annotate it |
  ///
  /// Only the last is fixed by the annotation, which is why they are told
  /// apart: a `Set` and a `Map<int, …>` have no class of their own to
  /// annotate, and a `List<Thing>` stays an unsupported shape however well
  /// `Thing` is annotated, because the element type is part of the stored
  /// name. A non-finite element keeps the `preferences.encode.not_json` key
  /// its top-level twin has — `[1.0, double.nan]` is a well-formed
  /// `List<double>` that [typeNameOf] names, so the defect is the number, not
  /// the shape.
  static String encodeValue(Object value, [String key = '']) {
    final scalar = _scalarOf(value);
    if (scalar != null) {
      try {
        return jsonEncode(scalar.toJson(value));
      } catch (error, stack) {
        // JSON has no NaN and no Infinity, so there is nothing to write and
        // nothing to fall back on — a substitute would be a different value
        // read back as if it were the one stored.
        throw TomUserPreferenceCodecException(
          'preferences.encode.not_json',
          '${_subjectOf(key)} holds the ${value.runtimeType} value $value, '
              'which JSON cannot represent. Store a finite number, or a '
              'String naming the special case.',
          parameters: {
            'key': key,
            'valueType': value.runtimeType.toString(),
            'value': value.toString(),
            'cause': 'value_not_json',
          },
          rootException: error,
          stack: stack,
        );
      }
    }
    if (value is Enum) {
      // As an object rather than a bare string, so that "a non-scalar value is
      // a JSON object" stays true without exception. That is what lets
      // [validateEncoded] keep checking the shape from the declared type name
      // alone, which is the one thing it must be able to do without reflecting
      // a class the server may not have.
      return jsonEncode({enumNameField: value.name});
    }
    try {
      // A collection needs no envelope: an array and an object are JSON's own
      // shapes, and the element type is already in the stored name, so there is
      // nothing a wrapper would add but a second thing for a non-Dart client to
      // know. `toEncodable` exists only for `DateTime` elements, which follow
      // the same UTC rule one level down that a top-level instant does.
      if (value is List || value is Map) {
        return jsonEncode(value, toEncodable: _encodeNested);
      }
      return tomReflectionInfo.convertToJsonString(value);
    } catch (error, stack) {
      throw _notEncodable(value, key, error, stack);
    }
  }

  /// The refusal for a value whose JSON text could not be written.
  ///
  /// The cause is worked out from the *value*, not from [error]. Both
  /// `jsonEncode` and the reflection registry report the same thing — "could
  /// not convert" — which is the one fact the caller already has. Five
  /// situations arrive here and they have five different remedies, and for
  /// four of them a `@tomReflector` annotation is not something the caller
  /// could add: a `Set` and a
  /// `Map<int, …>` have no class of their own to annotate, a `List<Thing>`
  /// stays an unsupported shape however well `Thing` is annotated, and a
  /// non-finite number is not a shape problem at all.
  ///
  /// Each refusal therefore names its own remedy, and carries a `cause`
  /// parameter — `element_not_json`, `map_key_not_string`,
  /// `element_not_scalar`, `not_a_list_or_map`, `unreflected_class` — so a
  /// caller that has to branch is not left parsing the prose. The top-level
  /// non-finite case, which has its own throw site, reports `value_not_json`.
  ///
  /// A non-finite *element* keeps `preferences.encode.not_json` rather than
  /// taking a shape key: `[1.0, double.nan]` is a perfectly well-formed
  /// `List<double>`, [typeNameOf] names it, and the defect is the same one a
  /// bare `double.nan` has. The same defect gets the same key.
  static TomUserPreferenceCodecException _notEncodable(
    Object value,
    String key,
    Object error,
    StackTrace stack,
  ) {
    final subject = _subjectOf(key);
    final valueType = value.runtimeType.toString();

    final nonFinite = _nonFiniteElementOf(value);
    if (nonFinite != null) {
      return TomUserPreferenceCodecException(
        'preferences.encode.not_json',
        '$subject holds $nonFinite as an element, and JSON has no NaN and no '
            'Infinity. Store finite numbers, or Strings naming the special '
            'cases.',
        parameters: {
          'key': key,
          'valueType': valueType,
          'value': nonFinite.toString(),
          'cause': 'element_not_json',
        },
        rootException: error,
        stack: stack,
      );
    }

    final foreignKeys = _foreignKeyTypesOf(value);
    if (foreignKeys != null) {
      return TomUserPreferenceCodecException(
        'preferences.encode.failed',
        '$subject is a Map keyed by $foreignKeys, and a JSON object has '
            'String keys. Key the map by String, or wrap it in a class '
            'annotated with @tomReflector if the keys have to stay what they '
            'are. There is deliberately no encoding convention for another '
            'key type: it would be one more thing a non-Dart reader of the '
            'row would have to know.',
        parameters: {
          'key': key,
          'valueType': valueType,
          'keyType': foreignKeys,
          'cause': 'map_key_not_string',
        },
        rootException: error,
        stack: stack,
      );
    }

    final foreignElement = _nonScalarElementTypeOf(value);
    if (foreignElement != null) {
      final shape = value is Map ? 'Map' : 'List';
      return TomUserPreferenceCodecException(
        'preferences.encode.failed',
        '$subject is a $shape holding an element of type $foreignElement, and '
            'a collection preference holds elements that are all one of '
            '${scalarTypes.join(', ')}. Annotating $foreignElement does not '
            'help: the element type is part of the stored name, so '
            '$shape<$foreignElement> is still no name a preference can be '
            'stored under. Wrap the whole collection in a class annotated '
            'with @tomReflector.',
        parameters: {
          'key': key,
          'valueType': valueType,
          'elementType': foreignElement,
          'cause': 'element_not_scalar',
        },
        rootException: error,
        stack: stack,
      );
    }

    if (value is Iterable) {
      // Named by what it is rather than by `runtimeType`, which for the SDK's
      // own iterables is a private class (`_Set`, `MappedListIterable`) that
      // tells the reader nothing they can act on.
      final shape = value is Set ? 'Set' : 'Iterable';
      return TomUserPreferenceCodecException(
        'preferences.encode.failed',
        '$subject is a $shape, and a collection preference must be a List or '
            'a Map<String, …> — JSON has an array and an object and nothing '
            'else. Store `toList()` of it, which makes the order part of the '
            'stored value, or wrap it in a class annotated with '
            '@tomReflector.',
        parameters: {
          'key': key,
          'valueType': valueType,
          'cause': 'not_a_list_or_map',
        },
        rootException: error,
        stack: stack,
      );
    }

    return TomUserPreferenceCodecException(
      'preferences.encode.failed',
      '$subject holds a $valueType, which the reflection registry could not '
          'encode. A preference value that is not a scalar and not a '
          'collection of scalars must be an instance of a class annotated '
          'with @tomReflector.',
      parameters: {
        'key': key,
        'valueType': valueType,
        'cause': 'unreflected_class',
      },
      rootException: error,
      stack: stack,
    );
  }

  /// The first element of [value] that JSON cannot write as a number.
  ///
  /// Only a `List` or a `Map` is looked at; a top-level non-finite scalar is
  /// caught at its own throw site, with its own wording.
  static num? _nonFiniteElementOf(Object value) {
    for (final element in _elementsOf(value)) {
      if (element is num && !element.isFinite) return element;
    }
    return null;
  }

  /// The distinct types of [value]'s keys that are not `String`, or `null`
  /// when it is not a `Map` or every key is one.
  static String? _foreignKeyTypesOf(Object value) {
    if (value is! Map) return null;
    final foreign = value.keys
        .where((candidate) => candidate is! String)
        .map((candidate) => candidate.runtimeType.toString())
        .toSet();
    return foreign.isEmpty ? null : foreign.join(', ');
  }

  /// The type of [value]'s first element that is not a scalar.
  ///
  /// `null` elements are skipped: JSON writes a null, so one is never the
  /// reason an encode failed, and reporting it would send the reader after
  /// the wrong element.
  static String? _nonScalarElementTypeOf(Object value) {
    for (final element in _elementsOf(value)) {
      if (element == null) continue;
      if (element is String ||
          element is num ||
          element is bool ||
          element is DateTime) {
        continue;
      }
      return element.runtimeType.toString();
    }
    return null;
  }

  /// What a `List` holds, or what a `Map` maps to. Nothing else has elements
  /// this class knows how to look through.
  static Iterable<Object?> _elementsOf(Object value) {
    if (value is List) return value;
    if (value is Map) return value.values;
    return const [];
  }

  /// Encodes a collection element `jsonEncode` cannot write by itself.
  ///
  /// Rendered by the element's own row — [_ScalarKind.toJson] — so an element
  /// is written exactly as a top-level value of that type is. Today only
  /// [DateTime] reaches here, the other four shapes being JSON's own; asking
  /// the row rather than naming `DateTime` is what keeps that true of the next
  /// scalar too, whose collections would otherwise fail to encode while the
  /// scalar itself encoded fine.
  ///
  /// Anything the table does not claim is rejected rather than given a
  /// `toString()` fallback: a fallback would write text no reader could turn
  /// back into the value, and [encodeValue] would report success.
  static Object _encodeNested(Object? value) {
    if (value != null) {
      final scalar = _scalarOf(value);
      if (scalar != null) return scalar.toJson(value);
    }
    throw JsonUnsupportedObjectError(value);
  }

  /// Checks that [valueJson] is JSON and is shaped like a [valueType].
  ///
  /// For the boundary: a write request arrives with the value *already*
  /// encoded, so nothing on the way in has proved that the declared type and
  /// the text agree. Storing a disagreeing pair costs nothing now and fails
  /// every future read of that key — including reads on other devices, which is
  /// where it would be found.
  ///
  /// A *reflected* [valueType] is only required to be a JSON object. Which
  /// class it names is deliberately not checked: a preference type may be one
  /// only the client knows, and a server that insisted on reflecting it would
  /// refuse to store values it is not meant to interpret.
  ///
  /// A **collection** is the exception, and gets a complete check — every
  /// element against the element type, and every instant against the zone rule.
  /// Not a stricter policy, the same one: the element type is part of the
  /// stored name, so verifying it asks the server nothing it does not already
  /// have. This is what a class name cannot offer, and the reason collections
  /// are a first-class shape rather than something to wrap.
  ///
  /// That is also why an enum is stored as an object: this check sees a type
  /// *name* and cannot tell an enum from a class without reflecting it, so
  /// giving enums a shape of their own would mean either weakening the rule
  /// for every class or asking the server the question it must not ask.
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
    final parts = _collectionParts(valueType);
    final bool matches;
    if (scalarTypes.contains(valueType)) {
      matches = _scalarMatches(valueType, raw);
    } else if (parts == null) {
      matches = raw is Map<String, Object?>;
    } else if (parts.isMap) {
      matches =
          raw is Map<String, Object?> &&
          raw.values.every((v) => _scalarMatches(parts.element, v));
    } else {
      matches =
          raw is List<Object?> &&
          raw.every((v) => _scalarMatches(parts.element, v));
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
    // whose local zone nobody knows yet. A list of instants is exactly as
    // ambiguous as a single one, so the question is asked of every position the
    // declared type says holds one.
    for (final text in _instantTexts(valueType, parts, raw)) {
      if (parseInstant(text) != null) continue;
      throw TomUserPreferenceCodecException(
        'preferences.encoded.not_an_instant',
        "Preference '$key' was written as a $valueType, but '$text' names no "
            'time zone, so it would be read as a different instant on every '
            'device. Write it in UTC (a trailing Z) or with an explicit '
            'offset.',
        parameters: {'key': key, 'valueType': valueType, 'value': text},
      );
    }
  }

  /// Whether [raw] is shaped like the scalar named [scalarType].
  ///
  /// Shared by [validateEncoded]'s top level and its element check, so that
  /// "what an `int` looks like in JSON" is answered once — and answered out of
  /// the same [_scalars] rows [typeNameOf] writes the name from, so a shape the
  /// codec can write is by construction a shape it will read back.
  ///
  /// `false` for a name no row claims, which is how a `valueType` naming a
  /// class reaches [validateEncoded]'s object branch rather than being mistaken
  /// for an unrecognised scalar.
  static bool _scalarMatches(String scalarType, Object? raw) =>
      _scalarNamed(scalarType)?.matchesJson(raw) ?? false;

  /// Every text in [raw] that the declared [valueType] says is an instant.
  ///
  /// [parts] is the collection [valueType] was already parsed into, passed
  /// rather than re-derived so the two cannot disagree about what the name
  /// means.
  static Iterable<String> _instantTexts(
    String valueType,
    ({bool isMap, String element})? parts,
    Object? raw,
  ) sync* {
    if (valueType == dateTimeType) {
      if (raw is String) yield raw;
      return;
    }
    if (parts == null || parts.element != dateTimeType) return;
    final elements = parts.isMap
        ? (raw is Map<String, Object?> ? raw.values : const <Object?>[])
        : (raw is List<Object?> ? raw : const <Object?>[]);
    for (final element in elements) {
      if (element is String) yield element;
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
  /// **A collection comes back as the exact `List<E>` or `Map<String, E>` it
  /// was stored as**, not as a `List<dynamic>` the caller has to cast: the
  /// element type is in the stored name, so the read knows it. Every element
  /// obeys the rule its own type obeys one level up — the zone check and the
  /// widening included — so a `List<double>` reads a JSON `[1, 2]` back as
  /// `[1.0, 2.0]`, and a list holding one zoneless timestamp is refused whole.
  ///
  /// **A reflected [T] is rebuilt member by member.** A JSON member the class
  /// does not declare is ignored, and a member the class declares but the
  /// payload omits keeps its declared default. The `valueType` comparison is
  /// what makes that safe: a caller asking for the wrong class is refused
  /// before a single member is assigned.
  ///
  /// **An enum [T] is matched against the constants it declares now**, and a
  /// stored name that is not among them raises
  /// `preferences.decode.unknown_enum_constant` rather than defaulting. The
  /// tolerance the class path allows is deliberately absent here: an omitted
  /// member falls back to the value the class itself declares, whereas an
  /// unmatched constant has no such answer — only the user's actual choice
  /// would do, and that is precisely what has been lost.
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
    return _decodeValue<T>(
      dto.value,
      dto.key,
      identity.name,
      identity.reflectedClass,
    );
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
  /// SDK type it can be a private name — a `Uri` renders as `_SimpleUri`,
  /// which no caller can write and therefore no caller can read back. The
  /// registry name is a literal the generator emits, so it survives all three.
  ///
  /// A **collection** is named by neither route: its name is composed from
  /// this class's own constants (`List<String>`), which has the same property
  /// for the same reason — nothing in it is a compiler rendering. That is why a
  /// `Map<String, int>` is storable although a map literal's runtime class is
  /// the private `_Map`.
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
    for (final scalar in _scalars) {
      if (scalar.dartType == type) {
        return (name: scalar.name, reflectedClass: null);
      }
    }
    final collection = _collectionTypes[type];
    if (collection != null) return (name: collection, reflectedClass: null);
    // `List` *is* `List<dynamic>`, so a caller who wrote the bare literal lands
    // here and would otherwise be told the registry does not know it — which is
    // false, and would send them looking for the wrong fix.
    if (type == List || type == Map || type == Set || type == Iterable) {
      throw _unsupportedCollection(type, key);
    }
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

  /// How a refusal refers to the value it is about.
  ///
  /// [key] is optional throughout the write path, because a caller may encode
  /// or name a value before it has decided where to put it — so every message
  /// has to read correctly without one.
  static String _subjectOf(String key) =>
      key.isEmpty ? 'A preference value' : "Preference '$key'";

  static TomUserPreferenceCodecException _noStoredIdentity(
    Type type,
    String key,
    Object? error,
    StackTrace? stack,
  ) {
    final subject = _subjectOf(key);
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

  /// Raised for a collection that is not one of the ten supported shapes.
  ///
  /// A key of its own rather than `preferences.type.not_reflected`, because for
  /// a `List<Object>` that message is untrue twice over: the registry *does*
  /// know `List`, and annotating the value is not something the caller can do
  /// to a collection. The advice a caller can act on is the restriction itself,
  /// so the message states it.
  static TomUserPreferenceCodecException _unsupportedCollection(
    Type type,
    String key,
  ) {
    final subject = _subjectOf(key);
    return TomUserPreferenceCodecException(
      'preferences.type.unsupported_collection',
      '$subject is a $type, which is not a preference value. A collection '
          'preference must be a List or a Map<String, …> whose elements are '
          'all one of ${scalarTypes.join(', ')} — the element type is part of '
          'the stored name, which is what lets the value be read back and '
          'checked. Wrap anything else in a class annotated with '
          '@tomReflector.',
      parameters: {'key': key, 'valueType': type.toString()},
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
  /// [storedName] is the name [decode] resolved [T] to and has already matched
  /// against the row, and [reflectedClass] is the registry entry behind it, or
  /// `null` when [T] is a scalar or a collection. Both are passed rather than
  /// looked up again because [decode] cannot have compared the stored name
  /// without resolving them, and a second lookup could only either repeat that
  /// work or disagree with it.
  ///
  /// Private, and deliberately so. Given the text alone there is nothing to
  /// contradict the caller's [T]: a stored `DateTime` read as a `String`
  /// succeeds here, because `"2026-03-04T05:06:07Z"` *is* a string. Only the
  /// stored [TomUserPreferenceDto.valueType] says otherwise, so [decode]
  /// compares it first and is the sole caller.
  static T _decodeValue<T extends Object>(
    String json,
    String key,
    String storedName,
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
    if (reflectedClass == null) {
      // Driven by the stored name rather than by `T` — the same thing here,
      // since [decode] derived the name from `T`, but it is the form the
      // element rule needs too, so both levels narrow through one method.
      final parts = _collectionParts(storedName);
      if (parts != null) {
        return _decodeCollection<T>(raw, key, storedName, parts);
      }
      return _narrowScalar(storedName, raw, key, storedName) as T;
    }
    if (reflectedClass.isEnum) {
      return _decodeEnum<T>(raw, key, reflectedClass);
    }
    if (raw is Map<String, Object?>) {
      try {
        return tomReflectionInfo.createInstanceFromJson<T>(reflectedClass, raw);
      } catch (error, stack) {
        // Every failure of `createInstanceFromJson` is an exception — a class
        // with no usable default constructor, a `fromJson` that raises, a
        // payload the target rejects. Uncaught, those reach the caller as
        // reflection errors, which is not the exception type this module tells
        // anyone to catch; the cause is kept rather than discarded.
        throw TomUserPreferenceCodecException(
          'preferences.decode.failed',
          "Preference '$key' could not be instantiated as $T. A reflected "
              'preference type needs a no-argument constructor, or a '
              '`fromJson` one.',
          parameters: {'key': key, 'requested': T.toString()},
          rootException: error,
          stack: stack,
        );
      }
    }
    throw _notDecodable(key, T.toString());
  }

  /// Narrows the decoded JSON [raw] to the scalar named [scalarType].
  ///
  /// [requested] is the type the *caller* asked for, which is [scalarType] at
  /// the top level and the whole collection name — `List<DateTime>` — when this
  /// is narrowing an element. It appears only in errors, so that a bad element
  /// is reported against the preference the reader actually asked for.
  ///
  /// The narrowing itself belongs to the row — [_ScalarKind.narrow] — so that
  /// a scalar is described in one place on both sides of the column. What is
  /// here is the single failure text for "not decodable as the requested
  /// type", which every row would otherwise state for itself.
  ///
  /// An `int` widens to a `double` — for the *row*, not for the reader. JSON
  /// writes `1.0` as `1`, so a `double` preference a non-Dart client wrote
  /// arrives integral, and [validateEncoded] admits it on that understanding:
  /// the read-side predicate for `double` is `is num`. The widening is the
  /// second half of that admission, and the two now sit in the same row, so
  /// removing one and keeping the other would take an edit that reads wrong.
  ///
  /// A caller reading an `int`-declared preference as a `double` never gets
  /// here. [decode] compares the stored name against the requested one before
  /// any narrowing, and refuses — the widening is not a way around a declared
  /// type.
  ///
  /// A `DateTime` must name its zone — see [_narrowInstant] and
  /// [parseInstant].
  static Object _narrowScalar(
    String scalarType,
    Object? raw,
    String key,
    String requested,
  ) {
    final narrowed = _scalarNamed(scalarType)?.narrow(raw, key, requested);
    if (narrowed != null) return narrowed;
    throw TomUserPreferenceCodecException(
      'preferences.decode.failed',
      "Preference '$key' could not be decoded as $requested.",
      parameters: {'key': key, 'requested': requested},
    );
  }

  /// Narrows the stored text of a [dateTimeType] row to the instant it names.
  ///
  /// The [_ScalarKind.narrow] of the `DateTime` row, written out rather than
  /// inlined into the table: the other four narrowings are a type test and a
  /// value, and this one has a rule to state and two errors to tell apart.
  ///
  /// A timestamp that names no zone is *refused*, not read as local. Reading it
  /// would have to invent an offset — this device's — and a preference follows
  /// its user across devices, so the invented instant would differ from the one
  /// the writer meant, differently on each of them. Text that is not a
  /// timestamp at all is a different failure and says so, because "not an
  /// instant" would send a reader looking for a zone in a value that has no
  /// date in it.
  ///
  /// `null` only for a [raw] that is not a `String`, which is the plain
  /// mismatch [_narrowScalar] reports for every row.
  static Object? _narrowInstant(Object? raw, String key, String requested) {
    if (raw is! String) return null;
    final instant = parseInstant(raw);
    if (instant != null) return instant;
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
          : "Preference '$key' was read as a $requested but its text is not a "
                'timestamp.',
      parameters: {'key': key, 'requested': requested, 'value': raw},
    );
  }

  /// Rebuilds the collection [storedName] describes from the decoded JSON
  /// [raw].
  ///
  /// The elements are narrowed one at a time by [_narrowScalar], so an element
  /// obeys exactly the rule a top-level value of that type obeys — the zone
  /// check and the `int`-to-`double` widening included — rather than a second,
  /// looser copy of it.
  ///
  /// The typed collection is built by the same row, through
  /// [_ScalarKind.listFrom] / [_ScalarKind.mapFrom]. It has to be *typed*: a
  /// `List<Object>` would satisfy the cast below in name only and fail the
  /// caller at the first use. Reading the constructor out of the row rather
  /// than out of a `switch` is what makes a sixth scalar one row rather than
  /// one row and two edits made somewhere else.
  static T _decodeCollection<T extends Object>(
    Object? raw,
    String key,
    String storedName,
    ({bool isMap, String element}) parts,
  ) {
    // Only a scalar element reaches here: `parts` came from
    // [_collectionParts], which recognises nothing else, so the row exists.
    final element = _scalarNamed(parts.element)!;
    if (parts.isMap) {
      if (raw is! Map<String, Object?>) {
        throw _notDecodable(key, storedName);
      }
      return element.mapFrom({
            for (final entry in raw.entries)
              entry.key: _narrowScalar(
                parts.element,
                entry.value,
                key,
                storedName,
              ),
          })
          as T;
    }
    if (raw is! List<Object?>) throw _notDecodable(key, storedName);
    return element.listFrom([
          for (final value in raw)
            _narrowScalar(parts.element, value, key, storedName),
        ])
        as T;
  }

  /// Raised when a stored row is not shaped like the type it was read as.
  static TomUserPreferenceCodecException _notDecodable(
    String key,
    String requested,
  ) => TomUserPreferenceCodecException(
    'preferences.decode.failed',
    "Preference '$key' could not be decoded as $requested.",
    parameters: {'key': key, 'requested': requested},
  );

  /// Resolves the enum constant [raw] names, against the constants [enumClass]
  /// declares *now*.
  ///
  /// Refused rather than defaulted when nothing matches. This is not a
  /// hypothetical: the row may have been written by a release whose enum had a
  /// constant this one has dropped or renamed, which is the ordinary cost of
  /// letting an enum evolve. Falling back to the first constant would hand the
  /// caller a setting the user never chose, and it would look exactly like one
  /// they did — so the read fails and says which name it could not place.
  static T _decodeEnum<T extends Object>(
    Object? raw,
    String key,
    ClassMirror enumClass,
  ) {
    final name = raw is Map<String, Object?> ? raw[enumNameField] : null;
    // The registry emits `values` for every enum it captures, and the same
    // capability that resolved the class supplies it.
    final constants = enumClass.invokeGetter('values') as List<Enum>;
    for (final constant in constants) {
      if (constant.name == name) return constant as T;
    }
    throw TomUserPreferenceCodecException(
      'preferences.decode.unknown_enum_constant',
      "Preference '$key' holds the $T constant '$name', which $T no longer "
          'declares. It has: ${constants.map((c) => c.name).join(', ')}.',
      parameters: {
        'key': key,
        'requested': T.toString(),
        'value': name?.toString() ?? '',
      },
    );
  }
}

/// One scalar shape: the Dart type it is, the name it is stored under, and the
/// two questions the codec asks about it.
///
/// One row rather than parallel lists, because it is one fact. That `int` is
/// stored as `int`, is recognised by `is int`, and looks like a JSON integer is
/// a single sentence about a single shape. Split across a list of names, a
/// chain of `is` tests, a chain of `Type` comparisons and a `switch` over those
/// names, the parts can fall out of step without anything failing to compile —
/// and a name the write side produces that the read side will not accept is a
/// preference that stores successfully and never comes back.
///
/// The two predicates are deliberately not one. They are asked on opposite
/// sides of the column: [matchesValue] of a live Dart value on the way in,
/// [matchesJson] of whatever `jsonDecode` returned on the way out. `double` is
/// where that shows — `is double` going in, `is num` coming back.
class _ScalarKind {
  /// Creates a row of the scalar table.
  ///
  /// Named rather than positional: a row states eleven things about one scalar,
  /// and eleven positional arguments is a table nobody can read a row of
  /// without counting commas against the constructor.
  const _ScalarKind({
    required this.dartType,
    required this.name,
    required this.matchesValue,
    required this.matchesJson,
    required this.toJson,
    required this.narrow,
    required this.listType,
    required this.mapType,
    required this.isListOf,
    required this.isMapOf,
    required this.listFrom,
    required this.mapFrom,
  });

  /// The Dart type this shape is, as a caller names it when reading a
  /// preference back by type rather than by value.
  ///
  /// Matched by [TomUserPreferenceCodec.typeNameForType], which asks its
  /// question of a `Type` and so cannot use [matchesValue] — there is no value
  /// yet. Same row, same answer, one place to add the next scalar.
  final Type dartType;

  /// The [TomUserPreferenceDto.valueType] a value of this shape is stored
  /// under.
  final String name;

  /// Whether a Dart value has this shape — the write side's question, asked by
  /// [TomUserPreferenceCodec.typeNameOf].
  final bool Function(Object value) matchesValue;

  /// Whether decoded JSON has this shape — the read side's question, asked by
  /// [TomUserPreferenceCodec.validateEncoded].
  final bool Function(Object? raw) matchesJson;

  /// The JSON-ready form of a Dart value of this shape, asked by
  /// [TomUserPreferenceCodec.encodeValue].
  ///
  /// Identity for the four shapes JSON has of its own; `DateTime` is the one
  /// that has to be rendered, and it renders in UTC because a preference
  /// follows its user across devices — see
  /// [TomUserPreferenceCodec.dateTimeType].
  final Object Function(Object value) toJson;

  /// Turns decoded JSON into the Dart value of this shape, or `null` when
  /// [raw] is not of this shape.
  ///
  /// The counterpart of [matchesJson] on the way out, and in the same row for
  /// the same reason: a shape the codec admits at the boundary has to be one it
  /// can then build. `double` is where the pair earns its keep — its
  /// [matchesJson] is `is num`, because JSON writes `1.0` as `1`, and this is
  /// the widening that admission promises.
  ///
  /// `null` rather than a throw for a plain mismatch, so that the one error
  /// text for "not decodable as the requested type" lives at the single call
  /// site instead of once per row. A row that has *more* than that to say —
  /// `DateTime`, whose text explains why an unzoned timestamp is refused rather
  /// than guessed — throws its own, which is why the signature carries [key]
  /// and [requested].
  final Object? Function(Object? raw, String key, String requested) narrow;

  /// The `Type` a caller reads a list of this shape back as — `List<String>`
  /// for the `String` row.
  ///
  /// A `Type` literal and not something composed, because there is nothing to
  /// compose it from: `List<T>` for a `T` held in a variable is not a type a
  /// Dart expression can name. That is the whole reason this belongs in the
  /// row — the row is the one place the element type is written as a *type*
  /// rather than as a name.
  final Type listType;

  /// The `Type` a caller reads a map of this shape back as.
  final Type mapType;

  /// Whether [value] is a list of this shape.
  ///
  /// An `is` test rather than a `runtimeType` comparison against [listType],
  /// because a runtime class is not the declared one: a decoded list is a
  /// `JSArray` under dart2js and a map literal is a `_Map`, neither of which is
  /// `== List<String>`.
  final bool Function(Object value) isListOf;

  /// Whether [value] is a map of this shape, keyed by `String`.
  final bool Function(Object value) isMapOf;

  /// Builds the typed `List` of this shape from already-narrowed values.
  ///
  /// The declared element type is what makes the decoded collection usable —
  /// `List<Object>` would satisfy the cast in name only and fail the caller's
  /// `as List<DateTime>` at the first use — and it is a thing only this row
  /// knows, so it belongs here rather than in a switch the reader has to keep
  /// in step with the table.
  final List<Object> Function(List<Object> values) listFrom;

  /// Builds the typed `Map` of this shape from already-narrowed values.
  ///
  /// The key is always `String`; see [TomUserPreferenceCodec.stringType].
  final Map<String, Object> Function(Map<String, Object> values) mapFrom;
}
