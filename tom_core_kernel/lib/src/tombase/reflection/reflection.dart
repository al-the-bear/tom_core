// ignore_for_file: type_literal_in_constant_pattern

import 'dart:convert';

import 'package:tom_basics/tom_basics.dart';
import 'package:tom_reflection/tom_reflection.dart';
import '../little_things/exception_base.dart';
import '../timezoned/date_timestamp.dart';
import '../json/json_serializable.dart';
import '../observable/tom_observable_objects.dart';

/// Exception thrown when reflection operations fail.
///
/// This exception is used throughout the reflection system to indicate
/// errors during:
/// - Instance creation from JSON
/// - Field value setting via reflection
/// - Type resolution for collections
/// - Serialization/deserialization operations
///
/// Example:
/// ```dart
/// try {
///   final instance = tomReflectionInfo.createInstance<MyClass>();
/// } on TomReflectorException catch (e) {
///   print('Reflection failed: ${e.defaultUserMessage}');
/// }
/// ```
class TomReflectorException extends TomException {
  /// Creates a new [TomReflectorException].
  ///
  /// - [key]: Unique identifier for this error type, used for i18n lookups.
  /// - [defaultUserMessage]: Human-readable error message.
  /// - [parameters]: Optional map of parameters for message interpolation.
  /// - [stack]: Optional stack trace.
  /// - [rootException]: Optional underlying exception that caused this error.
  /// - [autoLog]: Whether to automatically log this exception (default: false).
  TomReflectorException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A reflector configured with capabilities required for JSON serialization
/// and deserialization of annotated classes.
///
/// This reflector provides the following capabilities:
/// - **invokingCapability**: Call methods and constructors via reflection
/// - **typingCapability**: Access type information at runtime
/// - **typeRelationsCapability**: Navigate class hierarchies
/// - **reflectedTypeCapability**: Get actual Dart Type objects
/// - **typeAnnotationDeepQuantifyCapability**: Access nested type annotations
/// - **typeAnnotationQuantifyCapability**: Access type annotations
/// - **metadataCapability**: Access annotations and metadata
/// - **superclassQuantifyCapability**: Access superclass information
///
/// Usage:
/// ```dart
/// @tomReflector
/// class MyClass {
///   String name = '';
///   int age = 0;
/// }
/// ```
///
/// Classes must be annotated with `@tomReflector` to be discoverable
/// by the reflection system at runtime.
class TomReflector extends Reflection {
  /// Creates a new [TomReflector] with all required capabilities.
  const TomReflector()
    : super.fromList(const [
        invokingCapability,
        typingCapability,
        typeRelationsCapability,
        reflectedTypeCapability,
        typeAnnotationDeepQuantifyCapability,
        typeAnnotationQuantifyCapability,
        metadataCapability,
        superclassQuantifyCapability,
      ]);
}

/// Provides reflection-based operations for object serialization and deserialization.
///
/// This class is the main entry point for reflection operations in the Tom framework.
/// It provides methods to:
/// - Create instances of annotated classes
/// - Set values on objects from JSON/Maps
/// - Get values from objects as JSON/Maps
/// - Resolve element types from collections
///
/// ## Key Features
///
/// ### Instance Creation
/// Create new instances of annotated classes using the default constructor
/// or from JSON data:
/// ```dart
/// final person = tomReflectionInfo.createInstance<Person>();
/// final loaded = tomReflectionInfo.createInstanceFromJson<Person>(mirror, jsonData);
/// ```
///
/// ### Value Setting (Deserialization)
/// Set field values on objects from a map, handling:
/// - Primitive types (int, double, bool, String)
/// - DateTime and TomZoned* date/time types
/// - Nested objects (annotated with @tomReflector)
/// - Collections (List, Map) of primitives or annotated objects
///
/// ```dart
/// tomReflectionInfo.setValues(person, {'name': 'John', 'age': 30});
/// ```
///
/// ### Value Getting (Serialization)
/// Extract all field values from an object as a JSON-compatible map:
/// ```dart
/// final json = tomReflectionInfo.getValues(person);
/// final jsonString = tomReflectionInfo.convertToJsonString(person);
/// ```
///
/// ## There is exactly one reflector, and it is not a parameter
///
/// Every operation goes through the global [tomReflector]. The class used to
/// take a reflector as a constructor argument, which read as an extension
/// point and was not one: the code generator that produces the mirror data
/// refuses to emit anything for a class that is not a **direct** subclass of
/// `Reflection` (it warns *"An indirect subclass of `Reflection` will not work
/// as a reflector"* and skips it). [TomReflector] is that direct subclass, so
/// a subclass of *it* is one step too far and silently gets no data at all;
/// and because [TomReflector]'s constructor is `const`, every
/// `const TomReflector()` is canonicalised to the very same object as
/// [tomReflector]. The parameter could therefore only ever be handed the
/// global — or a value guaranteed to fail at the first mirror lookup.
///
/// Do not reintroduce it. A genuine second reflector would need a second
/// direct subclass of `Reflection` and a field typed to their common
/// supertype, which is a different design and one nothing currently asks for.
///
/// ## Debug Switches
/// Enable debug logging for troubleshooting reflection operations:
/// - [debugSwitchLogReflectionDetailsMembers]: Log class member information
/// - [debugSwitchLogReflectionDetailsValues]: Log value setting operations
/// - [debugSwitchLogReflectionDetailsTypes]: Log type resolution details
class TomReflectionInfo {
  /// When true, logs detailed member information during reflection operations.
  static bool debugSwitchLogReflectionDetailsMembers = false;

  /// When true, logs detailed value setting/getting operations.
  static bool debugSwitchLogReflectionDetailsValues = false;

  /// When true, logs type resolution information.
  static bool debugSwitchLogReflectionDetailsTypes = false;

  /// Handlers for setting primitive Map types via reflection.
  ///
  /// Maps type signatures to functions that set the value correctly, building
  /// a checked map for typed targets like `Map<String, int>`. The two
  /// unconstrained targets pass the source map through unchanged — there is no
  /// element type for them to violate.
  static final Map<
    Type,
    void Function(InstanceMirror, MapEntry<String, dynamic>)
  >
  _primitiveMapTypeHandlers = {
    Map<String, dynamic>: (im, e) => im.invokeSetter(e.key, e.value),
    Map<String, Object?>: (im, e) => im.invokeSetter(e.key, e.value),
    Map<String, Object>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<Object>(e)),
    Map<String, String>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<String>(e)),
    Map<String, String?>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<String?>(e)),
    Map<String, int>: (im, e) => im.invokeSetter(e.key, _checkedMap<int>(e)),
    Map<String, int?>: (im, e) => im.invokeSetter(e.key, _checkedMap<int?>(e)),
    Map<String, double>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<double>(e)),
    Map<String, double?>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<double?>(e)),
    Map<String, bool>: (im, e) => im.invokeSetter(e.key, _checkedMap<bool>(e)),
    Map<String, bool?>: (im, e) =>
        im.invokeSetter(e.key, _checkedMap<bool?>(e)),
  };

  /// Handlers for setting primitive List types via reflection.
  ///
  /// Maps type signatures to functions that set the value correctly, building
  /// a checked list for typed targets like `List<int>`. The two unconstrained
  /// targets pass the source list through unchanged — there is no element type
  /// for them to violate.
  static final Map<
    Type,
    void Function(InstanceMirror, MapEntry<String, dynamic>)
  >
  _primitiveListTypeHandlers = {
    List<Object?>: (im, e) => im.invokeSetter(e.key, e.value),
    List<dynamic>: (im, e) => im.invokeSetter(e.key, e.value),
    List<Object>: (im, e) => im.invokeSetter(e.key, _checkedList<Object>(e)),
    List<String>: (im, e) => im.invokeSetter(e.key, _checkedList<String>(e)),
    List<String?>: (im, e) => im.invokeSetter(e.key, _checkedList<String?>(e)),
    List<int>: (im, e) => im.invokeSetter(e.key, _checkedList<int>(e)),
    List<int?>: (im, e) => im.invokeSetter(e.key, _checkedList<int?>(e)),
    List<double>: (im, e) => im.invokeSetter(e.key, _checkedList<double>(e)),
    List<double?>: (im, e) => im.invokeSetter(e.key, _checkedList<double?>(e)),
    List<bool>: (im, e) => im.invokeSetter(e.key, _checkedList<bool>(e)),
    List<bool?>: (im, e) => im.invokeSetter(e.key, _checkedList<bool?>(e)),
  };

  /// Builds a `List<T>` from [entry]'s value, checking every element up front.
  ///
  /// Why not `.cast<T>()`: a cast view is *lazy*. It accepts a list holding an
  /// element of the wrong type without complaint and throws a bare `TypeError`
  /// only when that element is read — in another layer, another method, quite
  /// possibly another isolate, with a stack trace pointing at the consumer
  /// rather than at the payload that was wrong, and carrying neither the field
  /// name nor the source value. Worse, `length` and every well-typed element
  /// keep working, so a shallow post-deserialization check reports success.
  ///
  /// One pass up front costs a copy and moves the failure to the only place
  /// that still knows the field, the position and the offending value. It also
  /// makes the assignment atomic for primitive collections, which is what the
  /// module already promises for collections of annotated objects.
  static List<T> _checkedList<T>(MapEntry<String, dynamic> entry) {
    final source = entry.value as List;
    final result = <T>[];
    for (var i = 0; i < source.length; i++) {
      result.add(_checkedElement<T>(entry.key, "[$i]", source[i]));
    }
    return result;
  }

  /// Builds a `Map<String, T>` from [entry]'s value, checking it up front.
  ///
  /// The map counterpart of [_checkedList], which explains why a lazy `cast`
  /// will not do. Keys are checked as well as values: `cast<String, T>()`
  /// defers those too, and a non-`String` key reaches here from any caller
  /// that built its map in Dart rather than decoding it from JSON.
  static Map<String, T> _checkedMap<T>(MapEntry<String, dynamic> entry) {
    final source = entry.value as Map;
    final result = <String, T>{};
    for (var sourceEntry in source.entries) {
      final key = sourceEntry.key;
      if (key is! String) {
        throw TomReflectorException(
          "reflection.set.map_key_type_mismatch",
          "TomReflectionInfo.setValues: map field '${entry.key}' expects "
              "String keys but found the key '$key' of type "
              "${key.runtimeType}",
          parameters: {"key": entry.key},
          autoLog: true,
        );
      }
      final at = "['$key']";
      result[key] = _checkedElement<T>(entry.key, at, sourceEntry.value);
    }
    return result;
  }

  /// Returns [value] as a `T`, or reports why it is not one.
  ///
  /// [field] is the field being deserialized and [at] its position within the
  /// collection (`[2]`, `['name']`), so the message identifies the one element
  /// that is wrong rather than the whole payload.
  static T _checkedElement<T>(String field, String at, Object? value) {
    if (value is T) return value;
    // Widened for the same reason the scalar path widens (see
    // [_trySetWidenedNumericValue]): JSON and `key=value` command lines have
    // no int/double distinction, so `[1, 2]` for a `List<double>` is a pair of
    // whole-number doubles, not a type error. Only reachable when `value is T`
    // already said no, so this cannot intercept an int bound for an int.
    if (value is int && 0.0 is T) return value.toDouble() as T;
    throw TomReflectorException(
      "reflection.set.collection_element_type_mismatch",
      "TomReflectionInfo.setValues: '$field$at' expects $T but the value is "
          "${value == null ? 'null' : "'$value'"} of type ${value.runtimeType}",
      parameters: {"key": field, "at": at},
      autoLog: true,
    );
  }

  /// Whether [setValues] rejects a key that names no declaration on the target.
  ///
  /// False by default, which is what the shared [tomReflectionInfo] uses: on
  /// the wire, tolerating unknown keys is a feature. A newer client talking to
  /// an older server, or a stored document holding fields since removed, sends
  /// keys the target no longer declares, and failing the whole payload for
  /// them would make the format non-forward-compatible.
  ///
  /// Where the payload is under the caller's own control that tolerance is a
  /// liability instead, because it hides the commonest deserialization bug
  /// there is — a renamed field, or a typo, silently dropped. Construct a
  /// strict converter there:
  ///
  /// ```dart
  /// final strict = TomReflectionInfo(strictUnknownFields: true);
  /// strict.setValues(person, {'nickname': 'Jo'});
  /// // throws reflection.set.unknown_field
  /// ```
  ///
  /// It is a property of the converter rather than of the call so that nested
  /// objects inherit it: the walk recurses through [createInstanceFromJson] on
  /// this same instance, so a strict converter is strict all the way down.
  ///
  /// It governs unknown keys only. A key naming a member that exists but
  /// cannot be written is an error in both modes — see [_handleMissingField].
  final bool strictUnknownFields;

  /// Creates a converter over the global [tomReflector].
  ///
  /// It takes no reflector, and that is not an omission — see the class
  /// documentation for why a second one cannot exist. Prefer the shared
  /// [tomReflectionInfo] instance; construct your own only to choose a
  /// different [strictUnknownFields], which is the whole of the instance
  /// state.
  TomReflectionInfo({this.strictUnknownFields = false});

  // ---------------------------------------------------------------------------
  // Type Resolution Methods
  // ---------------------------------------------------------------------------

  /// Extracts the value type's [ClassMirror] from a Map type annotation.
  ///
  /// Given a `Map<K, V>` collection, this method extracts the type parameter `V`
  /// and returns its corresponding [ClassMirror].
  ///
  /// Example:
  /// ```dart
  /// Map<String, Person> people = {};
  /// final valueMirror = tomReflectionInfo.mapValueElementType(people);
  /// // valueMirror is the ClassMirror for Person
  /// ```
  ///
  /// Exactly two type arguments are required. A collection with any other
  /// arity is refused rather than resolved: with one, the caller wanted
  /// [singleElementType] and the message says so; with three or more, there is
  /// no "the value type" to return, and picking the second argument would be a
  /// guess that reads like an answer.
  ///
  /// Throws [TomReflectorException] if the value type is not found
  /// among annotated classes, or if it is itself generic — see
  /// [singleElementType] for why one level is the limit.
  ClassMirror mapValueElementType(Object collection) {
    final typeArguments = _topLevelTypeArguments(collection.runtimeType);
    if (typeArguments == null) {
      throw TomReflectorException(
        "reflector.type_resolution.not_a_generic_type",
        "TomReflectionInfo.mapValueElementType: '${collection.runtimeType}' "
            "is not a generic Map type (no type arguments found)",
        autoLog: true,
      );
    }
    if (typeArguments.length != 2) {
      throw TomReflectorException(
        "reflector.type_resolution.not_a_map_type",
        "TomReflectionInfo.mapValueElementType: '${collection.runtimeType}' "
            "is not a Map<K, V> type (expected two type arguments, "
            "found ${typeArguments.length})"
            "${_siblingHint(typeArguments.length, 1, "singleElementType")}",
        autoLog: true,
      );
    }
    return _resolveTypeArgument(
      typeArguments[1],
      collection,
      "mapValueElementType",
      "reflector.classmirror.not_found_for_map_value",
    );
  }

  /// Extracts the element type's [ClassMirror] from a single-type-parameter
  /// collection (e.g., List, Set).
  ///
  /// Given a `List<T>` or `Set<T>` collection, this method extracts the type
  /// parameter `T` and returns its corresponding [ClassMirror].
  ///
  /// Example:
  /// ```dart
  /// List<Person> people = [];
  /// final elementMirror = tomReflectionInfo.singleElementType(people);
  /// // elementMirror is the ClassMirror for Person
  /// ```
  ///
  /// Throws [TomReflectorException] if the element type is not found
  /// among annotated classes, or if it is itself generic: both methods resolve
  /// a name against the classes annotated with `@tomReflector`, and a generic
  /// instantiation such as `List<String>` is not one of those and never can be.
  /// One level of nesting is therefore the supported depth, and the exception
  /// says so rather than reporting a name that was never going to match.
  ///
  /// Exactly one type argument is required. Passing a `Map<K, V>` used to
  /// succeed and return the mirror for `K` — a valid mirror for the wrong half
  /// of the collection, which no caller could detect, so the arity is checked
  /// before the name is resolved.
  ClassMirror singleElementType(Object collection) {
    final typeArguments = _topLevelTypeArguments(collection.runtimeType);
    if (typeArguments == null) {
      throw TomReflectorException(
        "reflector.type_resolution.not_a_generic_type",
        "TomReflectionInfo.singleElementType: '${collection.runtimeType}' "
            "is not a generic collection type (no type argument found)",
        autoLog: true,
      );
    }
    if (typeArguments.length != 1) {
      throw TomReflectorException(
        "reflector.type_resolution.not_a_single_element_type",
        "TomReflectionInfo.singleElementType: '${collection.runtimeType}' "
            "is not a List<T> or Set<T> type (expected one type argument, "
            "found ${typeArguments.length})"
            "${_siblingHint(typeArguments.length, 2, "mapValueElementType")}",
        autoLog: true,
      );
    }
    return _resolveTypeArgument(
      typeArguments.first,
      collection,
      "singleElementType",
      "reflector.classmirror.not_found_for_iterable_value",
    );
  }

  /// The "you reached for the wrong method" clause, when the arity says so.
  ///
  /// [found] arguments point at [sibling] only when they are exactly the arity
  /// that sibling takes ([siblingArity]). Any other count is a shape neither
  /// resolver handles, and naming one that would refuse it too sends the reader
  /// in a circle.
  static String _siblingHint(int found, int siblingArity, String sibling) =>
      found == siblingArity ? "; use $sibling for this collection" : "";

  /// Splits the top-level type arguments out of [type]'s name.
  ///
  /// `Map<String, List<int>>` yields `['String', 'List<int>']`; a type with no
  /// arguments yields null.
  ///
  /// Why depth counting rather than a pattern: `<([^>]+)>` stops at the *first*
  /// closing bracket, which is the inner one as soon as an argument is itself
  /// generic — `List<List<String>>` came back as `List<String`, a name that
  /// matches nothing and reads, in the "could not be found" message that
  /// followed, like a typo in the framework rather than a limit of it.
  /// Splitting the arguments on `,` had the same bug one level down:
  /// `Map<String, Map<String, int>>` parsed to three arguments and picked
  /// `Map<String` as the value type. Only bracket depth distinguishes the
  /// separators that belong to this type from those that belong to its
  /// arguments.
  static List<String>? _topLevelTypeArguments(Type type) {
    final typeName = type.toString();
    final start = typeName.indexOf("<");
    if (start < 0 || !typeName.endsWith(">")) return null;
    final inner = typeName.substring(start + 1, typeName.length - 1);
    final typeArguments = <String>[];
    var depth = 0;
    var argumentStart = 0;
    for (var i = 0; i < inner.length; i++) {
      final character = inner[i];
      if (character == "<") {
        depth++;
      } else if (character == ">") {
        depth--;
      } else if (character == "," && depth == 0) {
        typeArguments.add(inner.substring(argumentStart, i).trim());
        argumentStart = i + 1;
      }
    }
    typeArguments.add(inner.substring(argumentStart).trim());
    return typeArguments;
  }

  /// Resolves one parsed type argument to its [ClassMirror].
  ///
  /// [method] and [collection] appear in the message so the caller can see
  /// which collection was being resolved, named as Dart names it.
  ClassMirror _resolveTypeArgument(
    String typeArgument,
    Object collection,
    String method,
    String notFoundErrorKey,
  ) {
    if (typeArgument.contains("<")) {
      throw _nestedGenericException(
        "TomReflectionInfo.$method",
        collection.runtimeType,
        typeArgument,
      );
    }
    return _findClassMirror(
      typeArgument,
      notFoundErrorKey,
      "TomReflectionInfo:elementType: ClassMirror for type $typeArgument "
      "could not be found",
    );
  }

  /// The exception every path raises when an element type is itself generic.
  ///
  /// [context] is the operation that hit it, [realType] the collection or field
  /// type spelled as Dart spells it, and [elementType] the argument that is
  /// generic. Both halves matter: `List<List<String>>` tells the reader which
  /// declaration to look at, `List<String>` which part of it is the problem.
  static TomReflectorException _nestedGenericException(
    String context,
    Object realType,
    String elementType,
  ) => TomReflectorException(
    "reflector.type_resolution.nested_generic_unsupported",
    "$context: '$realType' has the generic element type '$elementType'; "
        "nested generic collections are not supported — an element type must "
        "be a primitive, a date/time type, or a class annotated with "
        "@tomReflector",
    parameters: {"elementType": elementType},
    autoLog: true,
  );

  /// Raises [_nestedGenericException] if the field's type argument at
  /// [argumentIndex] is itself generic; returns quietly otherwise.
  ///
  /// Called from the *failure* branch of the two object-collection setters, not
  /// as a gate in front of them. Nothing that works today should start
  /// throwing: the check only replaces a diagnosis, and only once materializing
  /// the field has already failed.
  static void _throwIfNestedGeneric(
    MethodMirror imGet,
    String field,
    int argumentIndex,
  ) {
    final fieldType = imGet.reflectedReturnType;
    final typeArguments = _topLevelTypeArguments(fieldType);
    if (typeArguments == null || typeArguments.length <= argumentIndex) return;
    final typeArgument = typeArguments[argumentIndex];
    if (!typeArgument.contains("<")) return;
    throw _nestedGenericException(
      "TomReflectionInfo.setValues: field '$field'",
      fieldType,
      typeArgument,
    );
  }

  /// Finds a [ClassMirror] by type name among annotated classes.
  ///
  /// Searches through all classes annotated with `@tomReflector` to find
  /// one matching the given [typeName].
  ///
  /// Throws [TomReflectorException] with the provided [errorKey] and
  /// [errorMessage] if not found.
  ClassMirror _findClassMirror(
    String typeName,
    String errorKey,
    String errorMessage,
  ) {
    final matches = <ClassMirror>[];
    for (var t in tomReflector.annotatedClasses) {
      if (t.simpleName == typeName) {
        matches.add(t);
      }
    }
    if (matches.isEmpty) {
      throw TomReflectorException(errorKey, errorMessage, autoLog: true);
    }
    if (matches.length > 1) {
      // Resolving a type by its simple name is ambiguous when two annotated
      // classes share it across libraries: returning the first match risks
      // materializing the wrong type. Reject the lookup and name the collision.
      //
      // The collision is named by *library*, not by qualifiedName: the
      // reflector carries no libraryCapability, so every qualifiedName here is
      // ".$typeName" and listing them would repeat the ambiguous name back at
      // the reader instead of resolving it. The owning library's URI is the one
      // thing that differs, and it is what the fix — rename one, or drop its
      // annotation — needs to point at.
      final libraries = matches.map((m) => (m.owner as LibraryMirror).uri);
      throw TomReflectorException(
        "reflector.classmirror.ambiguous_simple_name",
        "TomReflectionInfo._findClassMirror: simple name '$typeName' is "
            "ambiguous; it matches annotated classes in "
            "${libraries.join(", ")}",
        autoLog: true,
      );
    }
    return matches.first;
  }

  /// Reflects [o] through the global [tomReflector] on behalf of [operation].
  ///
  /// The single door through which every instance-mirror lookup passes, so
  /// that the one thing that can go wrong here goes wrong the same way
  /// everywhere. That thing is an object whose class carries no
  /// `@tomReflector`: `tom_reflection` answers with a
  /// `NoSuchCapabilityError` naming the type and nothing else — not the
  /// operation that wanted it, not the annotation that would fix it, and not
  /// in the exception type the rest of this class raises. Callers that catch
  /// [TomReflectorException] would miss it entirely.
  ///
  /// [operation] is the public method the caller is inside, so the message
  /// says which of serialization, deserialization or reporting failed.
  InstanceMirror _reflect(Object o, String operation) {
    try {
      return tomReflector.reflect(o);
    } catch (e, s) {
      throw TomReflectorException(
        "reflector.reflect.not_reflectable",
        "TomReflectionInfo.$operation: cannot reflect on "
            "${o.runtimeType} — the class is not annotated with "
            "@tomReflector, or its generated reflection data was not "
            "initialized: $e",
        autoLog: true,
        rootException: e,
        stack: s,
      );
    }
  }

  /// Whether [cm] declares a constructor called [name].
  ///
  /// Constructors are not keyed by their own name in [ClassMirror.declarations]
  /// — `PersonWithFromJson.fromJson` is filed under
  /// `"PersonWithFromJson.fromJson"` — so the lookup is by
  /// [MethodMirror.constructorName] rather than by key.
  static bool _declaresConstructor(ClassMirror cm, String name) {
    return cm.declarations.values.any(
      (d) => d is MethodMirror && d.isConstructor && d.constructorName == name,
    );
  }

  /// Reports that an optional conversion hook ran and raised.
  ///
  /// The four hooks — the `fromJson` constructor, the `jsonDecode` method, the
  /// `toJson` method and the `jsonEncode` getter — are all *optional*. (The
  /// nominal form, [TomJsonSerializable], needs none of this: an `is` test
  /// cannot mistake absence for failure.) Detecting one by *trying*
  /// it inside an unqualified `catch` — whatever comes out, the hook is
  /// declared missing and the ordinary field-walking path takes over — would
  /// make a hook that does not exist and a hook that exists and is buggy the
  /// same event, and the second is the one worth hearing about: the caller's
  /// own code failed, and nothing would say so. The failure would then be
  /// attributed to the reflection layer, or to nothing at all.
  ///
  /// Each hook is therefore *looked up before it is called*, so absence is
  /// settled
  /// without running anything and the invocation itself is guarded only for
  /// the purpose of attribution. Nothing is inferred from the type of the
  /// failure, which matters because `tom_reflection` does not report
  /// absence in one consistent way: a missing constructor raises
  /// [NoSuchCapabilityError], but a missing method or getter surfaces as a
  /// plain `NoSuchMethodError` from a dynamic dispatch, because the generated
  /// getters map is shared across the whole reflector rather than per class.
  /// Catching by type would therefore keep the two cases fused for two hooks
  /// out of three, and would additionally re-fuse them for any hook whose own
  /// body happens to raise either error.
  static TomReflectorException _hookFailed(
    String hook,
    Object owner,
    Object error,
    StackTrace stack,
  ) {
    return TomReflectorException(
      "reflection.hook.failed",
      "$owner.$hook raised while converting; the hook exists, so this is "
          "not a missing hook but a failing one: $error",
      autoLog: true,
      rootException: error,
      stack: stack,
      parameters: {'hook': hook, 'owner': owner.toString()},
    );
  }

  /// Reports that an optional conversion hook ran, returned, and returned
  /// something unusable.
  ///
  /// Falling back to the field walk would be the quiet answer, and the wrong
  /// one: the hook exists precisely to replace that walk, so producing the
  /// representation it was written to override is not a recovery.
  static TomReflectorException _hookReturnedWrongType(
    String hook,
    Object owner,
    Object? value,
    String expected,
  ) {
    return TomReflectorException(
      "reflection.hook.invalid_return",
      "$owner.$hook returned ${value.runtimeType}, but $expected is "
          "required; the hook cannot be used and its result cannot be "
          "silently discarded",
      autoLog: true,
      parameters: {
        'hook': hook,
        'owner': owner.toString(),
        'expected': expected,
        'actual': value.runtimeType.toString(),
      },
    );
  }

  /// Resolves the class mirror of [im], insisting it carries `@tomReflector`.
  ///
  /// Reflecting successfully is not the same as being one of ours. The
  /// capability set includes deep type-annotation quantification, so every
  /// type that appears as a *field type* of an annotated class — `String`,
  /// `int`, `double`, `bool`, `DateTime`, `List`, `Map`, `Object` — gets
  /// generated data too. Those types reflect happily and then contribute no
  /// settable declarations, which is how `getValues('hello')` came to return
  /// `{}` and `convertToJsonString('hello')` the string `"{}"`: a
  /// valid-looking payload with every field dropped, reported as success.
  /// `setValues` was the mirror image, returning the object untouched.
  ///
  /// The test is the `@tomReflector` metadata rather than membership of
  /// [Reflection.annotatedClasses], for two independent reasons. That list
  /// holds the quantified types as well, so it cannot separate them; and it
  /// holds *declaration* mirrors, so the instantiated mirror of an annotated
  /// generic — `GenericHolder<int>` — is not in it, and a membership test
  /// would reject a class the developer did annotate. Metadata survives
  /// instantiation and marks exactly the annotated set.
  ///
  /// Resolving the mirror is itself inside the guard: for a generic
  /// instantiation the reflector does not own, `im.type` throws a bare
  /// `_TypeError` from inside `tom_reflection`, naming neither the type
  /// nor the operation.
  ClassMirror _annotatedType(InstanceMirror im, Object o, String operation) {
    ClassMirror classMirror;
    try {
      classMirror = im.type;
    } catch (e, s) {
      throw _notAnnotatedException(o, operation, e, s);
    }
    if (!classMirror.metadata.any((m) => m is TomReflector)) {
      throw _notAnnotatedException(o, operation, null, null);
    }
    return classMirror;
  }

  /// The exception raised when a target type is reflectable but not annotated.
  static TomReflectorException _notAnnotatedException(
    Object o,
    String operation,
    Object? rootException,
    StackTrace? stack,
  ) => TomReflectorException(
    "reflector.type.not_annotated",
    "TomReflectionInfo.$operation: ${o.runtimeType} is not annotated with "
        "@tomReflector, so it has no fields this converter may read or "
        "write; annotate the class and regenerate, or pass an instance of "
        "one that is${rootException == null ? '' : ': $rootException'}",
    autoLog: true,
    rootException: rootException,
    stack: stack,
  );

  // ---------------------------------------------------------------------------
  // Debug / Reporting Methods
  // ---------------------------------------------------------------------------

  /// Prints detailed reflection information about an object for debugging.
  ///
  /// This method reflects on the object's runtime type and prints:
  /// - All declarations (fields, methods, constructors)
  /// - Instance members with their types
  /// - Superclass hierarchy information
  ///
  /// Useful for debugging reflection issues or understanding class structure.
  ///
  /// Example:
  /// ```dart
  /// final person = Person();
  /// tomReflectionInfo.reportReflectObject(person);
  /// ```
  void reportReflectObject(Object o) {
    // Via the instance, so a generic value reports rather than throwing — see
    // [getValues]. Held to the same annotation check as the two converting
    // entry points: left out, it would be the one door still open, and it
    // printed a page of `Object`'s members for input it could tell nothing
    // about.
    const operation = 'reportReflectObject';
    reportReflect(_annotatedType(_reflect(o, operation), o, operation));
  }

  /// Prints detailed reflection information about a [ClassMirror] for debugging.
  ///
  /// Outputs:
  /// - Class name and reflected type status
  /// - All declarations with owner and metadata
  /// - Instance members with getter/setter/constructor info
  /// - Recursive superclass information
  void reportReflect(ClassMirror cm) {
    if (!cm.hasReflectedType) {
      print("${cm.simpleName} has no reflected type");
      return;
    }

    print("Reflecting on ${cm.simpleName}");
    _printDeclarations(cm);
    _printInstanceMembers(cm);
    _printSuperclass(cm);
  }

  /// Prints all declarations of a class.
  void _printDeclarations(ClassMirror cm) {
    print("Declarations: ");
    cm.declarations.forEach((key, value) {
      print(
        "$key: ${value.simpleName} Owner ${value.owner?.simpleName} ${value.metadata}",
      );
    });
  }

  /// Prints all instance members of a class.
  void _printInstanceMembers(ClassMirror cm) {
    print("Instance Members:");
    cm.instanceMembers.forEach((key, value) {
      try {
        final constructorInfo = value.isConstructor
            ? "constructor[${value.constructorName}]"
            : "";
        final getterInfo = value.isGetter ? "getter" : "";
        final setterInfo = value.isSetter ? "setter" : "";
        print(
          "$key: ${value.simpleName} $constructorInfo $getterInfo $setterInfo "
          "Reflected returntype ${value.returnType.simpleName} original ${value.returnType.isOriginalDeclaration}",
        );
      } catch (e) {
        print(
          "$key: ${value.simpleName} ${value.isGetter ? "getter" : ""} "
          "${value.isSetter ? "setter" : ""} Reflected returntype not available.",
        );
      }
    });
  }

  /// Prints superclass information recursively.
  void _printSuperclass(ClassMirror cm) {
    try {
      if (cm.superclass != null) {
        reportReflect(cm.superclass!);
      }
    } catch (e) {
      print("Failed to reflect superclass of ${cm.simpleName}");
    }
  }

  // ---------------------------------------------------------------------------
  // Instance Creation Methods
  // ---------------------------------------------------------------------------

  /// Creates an instance of type [T] from a JSON string.
  ///
  /// This method parses the JSON string and populates the fields of
  /// the provided object [o] with the parsed values.
  ///
  /// Example:
  /// ```dart
  /// final person = Person();
  /// tomReflectionInfo.convertFromJsonString(person, '{"name": "John", "age": 30}');
  /// print(person.name); // "John"
  /// ```
  ///
  /// Returns [o] with its fields populated — except for a class declaring a
  /// `fromJson` constructor, where it returns the instance that constructor
  /// built. Assign the result rather than reading [o] back; see [setValues].
  T convertFromJsonString<T extends Object>(T o, String s) {
    return setValues<T>(o, jsonDecode(s));
  }

  /// Creates a new instance of type [T] from a JSON string.
  ///
  /// Uses the provided [ClassMirror] to instantiate the object, then
  /// populates it from the parsed JSON.
  ///
  /// Returns the new instance. There is no failure value: every way this can
  /// go wrong throws. [s] is parsed before any reflection happens, so
  /// malformed JSON raises a [FormatException] from `jsonDecode`; everything
  /// after that is [createInstanceFromJson] and raises
  /// [TomReflectorException].
  T createInstanceFromJsonString<T extends Object>(
    ClassMirror objectMirror,
    String s,
  ) {
    return createInstanceFromJson(objectMirror, jsonDecode(s));
  }

  /// Creates a new instance of type [T] from JSON data.
  ///
  /// The inbound entry point for the case where there is no object yet. It
  /// honours the same hooks in the same order as [setValues] — see there for
  /// the precedence and why it is in that order — reaching them by the only
  /// route open to it: the `fromJson` constructor if the class declares one,
  /// otherwise the default constructor followed by [setValues], which settles
  /// [TomClass], `jsonDecode` and the field walk.
  ///
  /// The two entry points therefore agree. A class carrying a `fromJson`
  /// constructor decodes through it whichever of the two is called, which is
  /// what [setValues] gives up identity for.
  ///
  /// Example:
  /// ```dart
  /// final mirror = tomReflector.reflectType(Person) as ClassMirror;
  /// final person = tomReflectionInfo.createInstanceFromJson<Person>(
  ///   mirror,
  ///   {'name': 'Jane', 'age': 25},
  /// );
  /// ```
  ///
  /// Returns the new instance. There is no failure value: a class that cannot
  /// be built, a `fromJson` that raises, and a payload the target rejects all
  /// throw [TomReflectorException]. A caller testing the result for null is
  /// writing a branch that cannot be entered.
  T createInstanceFromJson<T extends Object>(
    ClassMirror objectMirror,
    Map<String, Object?> jsonData,
  ) {
    if (!_declaresConstructor(objectMirror, "fromJson")) {
      // No such constructor — build the object the ordinary way. This is the
      // only reason to fall back; see [_hookFailed].
      final T blank;
      try {
        blank = objectMirror.newInstance("", []) as T;
      } catch (error, stack) {
        // A mirror with no invocable default constructor raises
        // `tom_reflection`'s own NoSuchCapabilityError. Letting it out would
        // make this method's one documented failure mode a lie and hand the
        // caller an exception type this module never tells anyone to catch;
        // the same wrapping [createInstance] already applies, under the same
        // key.
        throw TomReflectorException(
          "reflector.instance_creation.failed",
          "Failed to create instance of type ${objectMirror.simpleName} "
              "from JSON: $error",
          autoLog: true,
          rootException: error,
          stack: stack,
        );
      }
      return setValues<T>(blank, jsonData);
    }

    return _invokeFromJson<T>(objectMirror, jsonData);
  }

  /// Invokes the `fromJson` constructor of [cm], which must declare one.
  ///
  /// Shared by [createInstanceFromJson] and [setValues] so that the two cannot
  /// drift: the hook is one hook, and a class must not decode differently
  /// depending on which entry point reached it. Callers check
  /// [_declaresConstructor] first — absence is settled before anything runs,
  /// per [_hookFailed], so everything caught here is a hook that exists and
  /// failed.
  T _invokeFromJson<T extends Object>(
    ClassMirror cm,
    Map<String, dynamic> jsonData,
  ) {
    final Object? built;
    try {
      built = cm.newInstance("fromJson", [jsonData]);
    } catch (error, stack) {
      throw _hookFailed('fromJson', cm.simpleName, error, stack);
    }

    if (built is T) return built;
    throw _hookReturnedWrongType('fromJson', cm.simpleName, built, '$T');
  }

  /// Creates a new instance using its default constructor.
  ///
  /// The class must be annotated with `@tomReflector` and have a default
  /// (no-argument) constructor.
  ///
  /// The type is named twice over, and the two are not the same question:
  /// [type] says *what to build*, [T] says *what to call the result* and is
  /// applied to it as a cast. Each defaults to the other, so most calls pass
  /// only one.
  ///
  /// ```dart
  /// // The type is known here; T carries it and the result is a Person.
  /// final person = tomReflectionInfo.createInstance<Person>();
  ///
  /// // Only a runtime Type is available. Nothing infers T, so it falls to its
  /// // bound: the instance is a Person, but the static type is Object.
  /// final instance = tomReflectionInfo.createInstance(someType);
  ///
  /// // Both: build someType, hand it back typed as a supertype it satisfies.
  /// final person = tomReflectionInfo.createInstance<Person>(someType);
  /// ```
  ///
  /// Passing both is only worthwhile when they differ, and nothing checks that
  /// they agree until the cast runs — a [type] that is not a [T] is not a
  /// compile error.
  ///
  /// Throws [TomReflectorException] (`reflector.instance_creation.failed`) if
  /// the class cannot be reflected or constructed, or if the result is not a
  /// [T].
  T createInstance<T extends Object>([Type? type]) {
    try {
      return (tomReflector.reflectType(type ?? T) as ClassMirror).newInstance(
            "",
            [],
          )
          as T;
    } catch (e, s) {
      throw TomReflectorException(
        "reflector.instance_creation.failed",
        "Failed to create instance of type ${type ?? T}: $e",
        autoLog: true,
        rootException: e,
        stack: s,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Value Setting Methods
  // ---------------------------------------------------------------------------

  /// Sets values on an object from a map of field names to values.
  ///
  /// This is **the** inbound entry point, and it honours every decoding hook
  /// the framework recognises. [createInstanceFromJson] resolves to the same
  /// order, so the answer does not depend on which of the two a caller
  /// happens to reach for.
  ///
  /// ## Precedence
  ///
  /// The first match wins:
  ///
  /// 1. **[TomClass]** — delegates to `TomClass.setValues()`, which knows how
  ///    to write observable fields. An `is` test.
  /// 2. **a `fromJson` constructor** — construction *is* the hook, so this
  ///    returns a **new instance** built from [values]; see below.
  /// 3. **a `jsonDecode` method** — invoked on [o], which decodes itself.
  /// 4. **the reflected fields** — written one by one.
  ///
  /// ## A `fromJson` class does not preserve identity
  ///
  /// Steps 1, 3 and 4 fill [o] and return it. Step 2 cannot: a constructor
  /// produces an object, it does not populate one, and a type that declares
  /// `fromJson` has said that building from a payload is *its* business. So
  /// for such a type this method returns the constructed instance and leaves
  /// [o] untouched.
  ///
  /// **Use the return value.** `converter.setValues(x, map)` and then reading
  /// `x` is correct for every other shape and wrong for this one; write
  /// `x = converter.setValues(x, map)`. The alternative — field-walking a
  /// `fromJson` type — would mean the same class decodes two different ways
  /// depending on the entry point, which is the asymmetry this ordering
  /// exists to remove.
  ///
  /// ## Supported Field Types
  ///
  /// - Primitive types: `int`, `double`, `bool`, `String`, `null`
  /// - DateTime types: `DateTime`, `TomZonedDate`, `TomZonedTime`, `TomZonedDateTime`
  /// - Nested objects: Any class annotated with `@tomReflector`
  /// - Collections: `List<T>` and `Map<String, T>` where T is a supported type
  ///
  /// Example:
  /// ```dart
  /// final person = Person();
  /// tomReflectionInfo.setValues(person, {
  ///   'name': 'John',
  ///   'age': 30,
  ///   'address': {'street': '123 Main St', 'city': 'NYC'},
  ///   'tags': ['developer', 'dart'],
  /// });
  /// ```
  ///
  /// Returns [o] with its fields populated, or — for a class declaring a
  /// `fromJson` constructor — the instance that constructor built.
  T setValues<T extends Object>(T o, Map<String, dynamic> values) {
    if (o is TomClass) {
      o.setValues(values);
      return o;
    }

    final im = _reflect(o, 'setValues');

    // From the instance mirror, not a second `reflectType(o.runtimeType)` —
    // see [getValues] for why that lookup cannot see a generic instantiation,
    // and [_annotatedType] for why reflecting successfully is not enough.
    // Resolved before the hook, so that a target which is not ours is
    // reported as such rather than as a hook that could not be found on it.
    final cm = _annotatedType(im, o, 'setValues');

    // Ahead of `jsonDecode`, matching [createInstanceFromJson]: when a type
    // declares both, the constructor is the more complete statement — it owns
    // the object from nothing, where the method only overwrites what is there.
    if (_declaresConstructor(cm, "fromJson")) {
      return _invokeFromJson<T>(cm, values);
    }

    if (_tryInvokeJsonDecode(im, cm, o, values)) {
      return o;
    }

    _logReflectionDetails(o, cm);

    for (var entry in values.entries) {
      _setFieldValue(im, cm, entry);
    }

    return o;
  }

  /// The keys of [values] that name no writable declaration on [o], in the
  /// order they appear.
  ///
  /// The question [strictUnknownFields] answers as it goes, asked in advance
  /// and answered for the whole map rather than for the first offender. A
  /// caller binding a document it owns — a configuration block, a settings
  /// map — uses this to report *every* misspelled key at once, in its own
  /// vocabulary and naming the document the keys came from, which is context
  /// this converter does not have and cannot invent.
  ///
  /// ```dart
  /// final unknown = tomReflectionInfo.unknownFields(driver, settings);
  /// if (unknown.isNotEmpty) throw MyConfigException(name, unknown);
  /// ```
  ///
  /// It applies the same rule as the field walk, so the two cannot drift: a
  /// key is unknown when the target declares neither a getter nor a setter for
  /// it. A member that exists but cannot be written — static, final, private —
  /// is **not** listed, because it is not unknown; [setValues] raises on it in
  /// both modes, which is where that fault belongs.
  ///
  /// Returns empty for a [TomClass], for a class declaring a `fromJson`
  /// constructor, and for one declaring a `jsonDecode` hook. Each of those
  /// takes the map over entirely, so what counts as a known key is theirs to
  /// define and this converter has no view of it — reporting their keys as
  /// unknown would be an answer to a question that was never asked here.
  List<String> unknownFields<T extends Object>(
    T o,
    Map<String, dynamic> values,
  ) {
    if (o is TomClass) return const [];

    final im = _reflect(o, 'unknownFields');
    final cm = _annotatedType(im, o, 'unknownFields');

    if (_declaresConstructor(cm, "fromJson")) return const [];
    if (cm.instanceMembers.containsKey("jsonDecode")) return const [];

    return [
      for (final key in values.keys)
        if (cm.instanceMembers[key] == null &&
            cm.instanceMembers['$key='] == null)
          key,
    ];
  }

  /// Invokes the optional `jsonDecode` hook, if [cm] declares one.
  ///
  /// Returns true when the hook ran, having taken over deserialization
  /// entirely. Returns false only when there is no such hook — a hook that
  /// exists and raises propagates rather than being mistaken for an absent
  /// one and quietly replaced by the field walk it was written to override.
  /// See [_hookFailed].
  bool _tryInvokeJsonDecode(
    InstanceMirror im,
    ClassMirror cm,
    Object o,
    Map<String, dynamic> values,
  ) {
    if (!cm.instanceMembers.containsKey("jsonDecode")) return false;

    try {
      im.invoke("jsonDecode", [values]);
      return true;
    } catch (error, stack) {
      throw _hookFailed('jsonDecode', o.runtimeType, error, stack);
    }
  }

  /// Logs reflection details when debug switches are enabled.
  void _logReflectionDetails(Object o, ClassMirror cm) {
    if (debugSwitchLogReflectionDetailsTypes) {
      tomLog.trace(
        "setting values, reflecting on ${o.runtimeType} ${cm.instanceMembers.length} instance members",
      );
    }
    if (debugSwitchLogReflectionDetailsMembers) {
      for (var decl in cm.instanceMembers.keys) {
        final mm = cm.instanceMembers[decl];
        tomLog.trace("Declaration found: $mm ${mm?.reflectedReturnType}");
      }
    }
  }

  /// Sets a single field value on an object via reflection.
  ///
  /// Handles primitive values directly, then falls back to complex
  /// value handling for Maps, Lists, and nested objects.
  void _setFieldValue(
    InstanceMirror im,
    ClassMirror cm,
    MapEntry<String, dynamic> entry,
  ) {
    if (debugSwitchLogReflectionDetailsValues) {
      tomLog.trace("Value found: ${entry.key} ${limited(entry.value, 80)}");
    }

    if (_trySetPrimitiveValue(im, entry)) return;

    final imSet = cm.instanceMembers["${entry.key}="];
    final imGet = cm.instanceMembers[entry.key];

    if (imGet != null && imSet != null) {
      _setComplexValue(im, cm, imGet, entry);
    } else {
      _handleMissingField(cm, imGet, imSet, entry);
    }
  }

  /// Attempts to set a primitive value directly via setter invocation.
  ///
  /// Returns true if the value was successfully set, false otherwise.
  bool _trySetPrimitiveValue(
    InstanceMirror im,
    MapEntry<String, dynamic> entry,
  ) {
    try {
      if (entry.value == null ||
          entry.value is int ||
          entry.value is double ||
          entry.value is bool ||
          entry.value is String) {
        im.invokeSetter(entry.key, entry.value);
        return true;
      }
    } catch (ex) {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "Can't set directly: ${entry.key} ${limited(entry.value, 80)}. Exception: $ex",
        );
      }
    }
    return false;
  }

  /// Handles an entry the field walk could not assign, of which there are two
  /// unrelated kinds.
  ///
  /// **The member exists but cannot be written** ([imGet] found, [imSet] not):
  /// a static, final or private declaration. Always an error, in both modes —
  /// the caller named a field this class has and asked for a value it will
  /// never hold.
  ///
  /// **No such member** (neither found): an unknown key. Silently traced, or
  /// rejected when [strictUnknownFields] is set; see that field for why the
  /// default is tolerance.
  ///
  /// A setter without a getter reaches the second case and is deliberately not
  /// reported as unknown — the member does exist, the walk simply has no
  /// return type to resolve the value against. Calling that "unknown field"
  /// would send the reader looking for a declaration that is right there.
  void _handleMissingField(
    ClassMirror cm,
    MethodMirror? imGet,
    MethodMirror? imSet,
    MapEntry<String, dynamic> entry,
  ) {
    if (imGet != null) {
      throw TomReflectorException(
        "reflection.set.unexpected_condition_final_static_private",
        "TomReflectionInfo.setValues: '${cm.simpleName}.${entry.key}' cannot "
            "be written — the value is ${entry.value} of type "
            "${entry.value.runtimeType} and the declaration is probably "
            "static, final or private.",
        parameters: {"key": entry.key},
        autoLog: true,
      );
    }

    if (imSet == null && strictUnknownFields) {
      throw TomReflectorException(
        "reflection.set.unknown_field",
        "TomReflectionInfo.setValues: '${cm.simpleName}' declares no field "
            "'${entry.key}', and this converter is strict about unknown "
            "fields. The value was ${limited(entry.value, 80)}.",
        parameters: {"key": entry.key},
        autoLog: true,
      );
    }

    if (debugSwitchLogReflectionDetailsValues) {
      tomLog.trace(
        "Found value/node ${entry.key} = ${entry.value} in values which do not correspond to declarations",
      );
    }
  }

  /// Sets a complex (non-primitive) value on a field.
  ///
  /// Handles int-to-double widening, String (for DateTime parsing), Map, and
  /// List values. Delegates to specialized handlers based on value type.
  void _setComplexValue(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    if (debugSwitchLogReflectionDetailsValues) {
      tomLog.trace(
        "Setting value ${limited(entry.value, 100)} of type "
        "${entry.value != null ? entry.value.runtimeType : 'null'} "
        "for field ${imGet.simpleName} of type ${imGet.reflectedReturnType}",
      );
    }

    if (_trySetWidenedNumericValue(im, imGet, entry)) {
      return;
    } else if (entry.value is String) {
      _setStringValue(im, cm, imGet, entry);
    } else if (entry.value is Map) {
      _setMapValue(im, cm, imGet, entry);
    } else if (entry.value is List) {
      _setListValue(im, cm, imGet, entry);
    } else {
      throw TomReflectorException(
        "reflection.set.unexpected_type",
        "Field '${entry.key}' of ${cm.simpleName}, declared as "
            "${imGet.reflectedReturnType}, cannot be set from a "
            "${entry.value.runtimeType} (${limited(entry.value, 100)}): the "
            "value is not assignable, and no strategy converts a value of that "
            "type.",
        parameters: _fieldRefusalParameters(
          cm.simpleName,
          entry.key,
          imGet.reflectedReturnType,
          entry.value,
        ),
        autoLog: true,
      );
    }
  }

  /// The parameters every refusal of a field's value carries: the class, the
  /// field, the field's declared type and the value's runtime type.
  ///
  /// The four are what locate a refusal in a payload. The key says how far the
  /// reflector got; these say *where*, and a payload is usually a whole JSON
  /// document. The value's type is named in its own right because the only
  /// other place it might appear is a root error in the Dart runtime's wording,
  /// and a refusal decided by inspection has no root error at all.
  static Map<String, Object?> _fieldRefusalParameters(
    String owner,
    String field,
    Object declaredType,
    Object? value, {
    String? at,
  }) => {
    "class": owner,
    "field": field,
    "declaredType": "$declaredType",
    "valueType": "${value.runtimeType}",
    if (at != null) "at": at,
  };

  /// The refusals raised by *building* a value — [createInstanceFromJson]
  /// finding no constructor it may call, and [setValues] finding a type with
  /// no reflected fields. Both are raised where only the type is known.
  static const Set<String> _buildRefusalKeys = {
    "reflector.instance_creation.failed",
    "reflector.type.not_annotated",
  };

  /// [error] re-raised with the field it was building a value for, or `null`
  /// when it should travel as it is.
  ///
  /// A build refusal names the type that would not build and nothing else,
  /// because that is all the builder knows: "Failed to create instance of type
  /// List" is true, and leaves the caller searching the payload for every
  /// field that might hold a list. When the value was being built for a field,
  /// the field is the part the caller needs, so the refusal is raised again
  /// with [_fieldRefusalParameters] — under the **same key**, since the key
  /// already says the right thing about what went wrong — and the original
  /// kept as its `rootException`. [at] names the element's position when the
  /// value was one element of a collection field.
  ///
  /// Only an unattributed build refusal is re-raised. Every other key is a
  /// verdict that already carries its own context, and a refusal that already
  /// names a field was claimed by a nested field closer to the fault:
  /// attribution is innermost, so an enclosing field must not overwrite it.
  static TomReflectorException? _attributedBuildRefusal(
    TomReflectorException error,
    StackTrace stack, {
    required String owner,
    required String field,
    required Object declaredType,
    required Object? value,
    String? at,
  }) {
    if (!_buildRefusalKeys.contains(error.key)) return null;
    if (error.parameters?["field"] != null) return null;
    return TomReflectorException(
      error.key,
      "Could not build a value for field '$field' of $owner, declared as "
      "$declaredType${at == null ? '' : ', at $at'}, from a "
      "${value.runtimeType} (${limited(value, 100)}): "
      "${error.defaultUserMessage}",
      parameters: {
        ...?error.parameters,
        ..._fieldRefusalParameters(owner, field, declaredType, value, at: at),
      },
      rootException: error,
      stack: stack,
      autoLog: true,
    );
  }

  /// Widens an `int` value onto a `double` field, returning true when it did.
  ///
  /// Why: the wire formats this reflector reads from — JSON and command-line
  /// `key=value` arguments — have no int/double distinction. `{"rate": 2}` and
  /// `rate=2` both decode to an `int`, and there is no way for the source to
  /// say "double". Rejecting them would make a whole-number double
  /// unrepresentable, so an `int` destined for a `double` field is widened.
  ///
  /// The converse is deliberately absent: narrowing a `double` to an `int`
  /// would need a rounding policy, and truncating `2.5` silently loses data.
  bool _trySetWidenedNumericValue(
    InstanceMirror im,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    if (entry.value is! int) return false;
    final returnType = imGet.reflectedReturnType;
    if (returnType != double) return false;
    im.invokeSetter(entry.key, (entry.value as int).toDouble());
    return true;
  }

  // ---------------------------------------------------------------------------
  // String Value Setting
  // ---------------------------------------------------------------------------

  /// Parses [text] into a date/time value, naming the site on failure.
  ///
  /// Why: `DateTime.parse` and the `TomZoned*` parsers throw a bare
  /// [FormatException] that carries the offending text and nothing else. Let
  /// out unwrapped it told a caller deserializing a thirty-field payload only
  /// that *something* in it was not a date — no field, no class, no position.
  /// It also escaped the module's auto-logging, so the one failure with no
  /// exception id was the one hardest to trace, and it slipped past a
  /// `catch (e) on TomReflectorException` written against the documented
  /// error table.
  ///
  /// [owner] is the class being filled, [field] the field being set, and [at]
  /// the position within a collection — a map key or a list index — or null
  /// for a scalar field, where the field name is already the whole story.
  static T _parseDateTimeString<T>(
    String text,
    T Function(String) parser, {
    required String owner,
    required String field,
    required Object targetType,
    String? at,
  }) {
    try {
      return parser(text);
    } on FormatException catch (e, s) {
      throw TomReflectorException(
        "reflection.set.date_parse_failed",
        "Cannot set field '$field' on $owner"
            "${at == null ? '' : ' at $at'}: "
            "\"$text\" is not a valid $targetType",
        autoLog: true,
        rootException: e,
        stack: s,
        parameters: {
          'owner': owner,
          'field': field,
          'targetType': targetType.toString(),
          'value': text,
          if (at != null) 'at': at,
        },
      );
    }
  }

  /// Sets a String value that represents a date/time type.
  ///
  /// Parses the string and converts to the appropriate DateTime type
  /// based on the field's declared return type. A string the target type
  /// cannot parse raises `reflection.set.date_parse_failed` rather than
  /// letting a context-free [FormatException] out; see
  /// [_parseDateTimeString].
  void _setStringValue(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final returnType = imGet.reflectedReturnType;

    T parse<T>(T Function(String) parser) => _parseDateTimeString<T>(
      entry.value,
      parser,
      owner: cm.simpleName,
      field: entry.key,
      targetType: returnType,
    );

    if (returnType == DateTime) {
      im.invokeSetter(entry.key, parse(DateTime.parse));
    } else if (returnType == TomZonedDate) {
      im.invokeSetter(entry.key, parse(TomZonedDate.parseFromString));
    } else if (returnType == TomZonedTime) {
      im.invokeSetter(entry.key, parse(TomZonedTime.parseFromString));
    } else if (returnType == TomZonedDateTime) {
      im.invokeSetter(entry.key, parse(TomZonedDateTime.parseFromString));
    } else {
      throw TomReflectorException(
        "reflection.set.unexpected_string_type",
        "Unexpected type $returnType set using String in set values: ${entry.key} is ${entry.value} of type ${entry.value.runtimeType}",
        autoLog: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Map Value Setting
  // ---------------------------------------------------------------------------

  /// Sets a Map value on a field.
  ///
  /// Handles multiple scenarios in order:
  /// 1. Primitive map types (`Map<String, int>`, etc.)
  /// 2. DateTime map types (`Map<String, DateTime>`, etc.)
  /// 3. Annotated object map types (`Map<String, MyClass>`)
  /// 4. Existing map/object filling
  /// 5. Instance creation and population
  void _setMapValue(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final returnType = imGet.reflectedReturnType;

    // Try primitive map types first
    if (_trySetPrimitiveMapType(im, returnType, entry)) return;

    // Try DateTime map types
    if (_trySetDateTimeMapType(im, cm, returnType, entry)) return;

    // Try annotated object map types
    if (_trySetAnnotatedObjectMapType(im, cm, imGet, entry)) return;

    // Try to fill existing object
    if (_tryFillExistingMapOrObject(im, cm, entry)) return;

    // Try to instantiate and fill
    if (_instantiateAndSetMapValue(im, cm, entry)) return;

    // Nothing claimed the payload. The caller named a field that genuinely
    // exists and handed it a value this reflector cannot turn into that
    // field's type, so the only two honest outcomes are to apply it or to say
    // so. Tracing instead — under a debug switch that defaults to false —
    // is neither: the field keeps its old value, `setValues` returns as though
    // the entry had been applied, and nothing at the call site can tell the
    // two apart.
    throw TomReflectorException(
      "reflection.set.map_field_not_settable",
      "No strategy could set map field '${entry.key}' of ${cm.simpleName}, "
          "declared as $returnType, from a ${entry.value.runtimeType} "
          "(${limited(entry.value, 100)}). The declared type is not a "
          "supported map type, names no reflected class to build, and the "
          "field holds nothing to fill in place.",
      parameters: _fieldRefusalParameters(
        cm.simpleName,
        entry.key,
        returnType,
        entry.value,
      ),
      autoLog: true,
    );
  }

  /// Attempts to set a primitive Map type using registered handlers.
  bool _trySetPrimitiveMapType(
    InstanceMirror im,
    Type returnType,
    MapEntry<String, dynamic> entry,
  ) {
    final handler = _primitiveMapTypeHandlers[returnType];
    if (handler != null) {
      handler(im, entry);
      return true;
    }
    return false;
  }

  /// Attempts to set a DateTime Map type (`Map<String, DateTime>`, etc.).
  bool _trySetDateTimeMapType(
    InstanceMirror im,
    ClassMirror cm,
    Type returnType,
    MapEntry<String, dynamic> entry,
  ) {
    bool set<T>(T Function(String) parser, {bool nullable = false}) {
      im.invokeSetter(
        entry.key,
        _parseStringMap<T>(
          entry,
          parser,
          owner: cm.simpleName,
          nullable: nullable,
        ),
      );
      return true;
    }

    if (returnType == Map<String, DateTime>) {
      return set<DateTime>(DateTime.parse);
    }
    if (returnType == Map<String, DateTime?>) {
      return set<DateTime?>(DateTime.parse, nullable: true);
    }
    if (returnType == Map<String, TomZonedDate>) {
      return set<TomZonedDate>(TomZonedDate.parseFromString);
    }
    if (returnType == Map<String, TomZonedDate?>) {
      return set<TomZonedDate?>(TomZonedDate.parseFromString, nullable: true);
    }
    if (returnType == Map<String, TomZonedTime>) {
      return set<TomZonedTime>(TomZonedTime.parseFromString);
    }
    if (returnType == Map<String, TomZonedTime?>) {
      return set<TomZonedTime?>(TomZonedTime.parseFromString, nullable: true);
    }
    if (returnType == Map<String, TomZonedDateTime>) {
      return set<TomZonedDateTime>(TomZonedDateTime.parseFromString);
    }
    if (returnType == Map<String, TomZonedDateTime?>) {
      return set<TomZonedDateTime?>(
        TomZonedDateTime.parseFromString,
        nullable: true,
      );
    }
    return false;
  }

  /// Parses a map of strings into typed datetime values.
  ///
  /// The result is built in full before the caller assigns it, so a single
  /// unparseable element leaves the target field holding its previous map.
  /// A parse failure names the field and the offending map key rather than
  /// escaping as a bare [FormatException]; see [_parseDateTimeString].
  static Map<String, T> _parseStringMap<T>(
    MapEntry<String, dynamic> entry,
    T Function(String) parser, {
    required String owner,
    bool nullable = false,
  }) {
    final result = <String, T>{};
    for (var element in (entry.value as Map).entries) {
      if (element.value is String) {
        result[element.key] = _parseDateTimeString<T>(
          element.value,
          parser,
          owner: owner,
          field: entry.key,
          targetType: T,
          at: "key '${element.key}'",
        );
      } else if (element.value == null && nullable) {
        result[element.key] = null as T;
      } else {
        throw TomReflectorException(
          "reflection.set.datetime_must_be_filled_from_string_in_map",
          "Attempt to set datetime from non-String element "
              "${element.key}: ${element.value}",
          autoLog: true,
        );
      }
    }
    return result;
  }

  /// Attempts to set a Map with annotated object values.
  ///
  /// For `Map<String, MyClass>` where MyClass is annotated with `@tomReflector`,
  /// this method creates instances of MyClass for each map entry.
  bool _trySetAnnotatedObjectMapType(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final typeString = imGet.reflectedReturnType.toString();
    if (!typeString.startsWith("Map<String,")) return false;
    final memberMirror = imGet.returnType.typeArguments[1] as ClassMirror;

    // No guard: the only caller dispatches here on `entry.value is Map`, and
    // `cast` is a lazy view that defers every element check to the read below.
    // A catch around this line could only decline for a reason that cannot
    // occur, while implying to the reader one that can.
    final jsonMap = (entry.value as Map).cast<String, Map<String, dynamic>?>();

    // Materialize every value into a fresh map first; only assign on full
    // success so a mid-stream failure never leaves the field half-populated.
    // A value rejected by the (non-nullable) target type surfaces
    // as a TomReflectorException instead of silently truncating the map.
    final newMap = typeString.endsWith("?>")
        ? memberMirror.createNullableValuedMap<String>()
        : memberMirror.createValuedMap<String>();
    String? building;
    try {
      for (var subEntry in jsonMap.entries) {
        building = subEntry.key;
        newMap[subEntry.key] = subEntry.value != null
            ? createInstanceFromJson(memberMirror, subEntry.value!)
            : null;
      }
    } on TomReflectorException catch (error, stacktrace) {
      final attributed = _attributedBuildRefusal(
        error,
        stacktrace,
        owner: cm.simpleName,
        field: entry.key,
        declaredType: imGet.reflectedReturnType,
        value: (entry.value as Map)[building],
        at: "key '$building'",
      );
      if (attributed == null) rethrow;
      throw attributed;
    } catch (error, stacktrace) {
      // A field whose value type is itself generic — `Map<String, List<X>>` —
      // cannot be materialized at all, and the cast error it produces names
      // neither the field's declared type (the mirror's simple name has
      // already dropped the inner argument, leaving `List`) nor the reason.
      // Diagnose it here rather than wrapping the symptom.
      _throwIfNestedGeneric(imGet, entry.key, 1);
      throw TomReflectorException(
        "reflection.set.map_value_materialization_failed",
        "Failed to materialize value of map field '${entry.key}' "
            "(Map<String, ${memberMirror.simpleName}>): $error",
        parameters: {"key": entry.key},
        rootException: error,
        stack: stacktrace,
        autoLog: true,
      );
    }

    // Atomic assignment: only now that the whole map is built do we touch the
    // target field, preserving its prior content if anything above threw.
    final existingMap = im.invokeGetter(entry.key) as Map?;
    if (existingMap == null) {
      im.invokeSetter(entry.key, newMap);
    } else {
      existingMap.clear();
      existingMap.addAll(newMap);
    }
    return true;
  }

  /// Attempts to fill an existing Map or object with values.
  ///
  /// If the field already contains a non-null Map or object,
  /// populates it with the provided values instead of replacing it.
  bool _tryFillExistingMapOrObject(
    InstanceMirror im,
    ClassMirror cm,
    MapEntry<String, dynamic> entry,
  ) {
    // Reading the field is the one operation here whose failure genuinely
    // means "this strategy does not apply": a `late` field that has not been
    // initialized throws rather than returning null, and "there is nothing in
    // the field to fill" is exactly what that says.
    final Object? existing;
    try {
      existing = im.invokeGetter(entry.key);
    } catch (_) {
      return false;
    }
    if (existing == null || entry.value is! Map<String, dynamic>) return false;

    // Past that guard this strategy applies: the field holds something and the
    // payload is a map for it. A failure from here on is a verdict on the
    // payload, not a signal to try the next strategy, so it is reported rather
    // than absorbed — absorbing it would demote a precise diagnosis to a
    // field silently left as it was.
    try {
      if (existing is Map<String, Object?>) {
        for (var valueEntry in (entry.value as Map<String, dynamic>).entries) {
          existing[valueEntry.key] = valueEntry.value;
        }
      } else {
        setValues(existing, entry.value as Map<String, dynamic>);
      }
    } on TomReflectorException catch (error, stacktrace) {
      // Pouring a map into what the field holds refuses the holder's *type*
      // when that type has no reflected fields — a list, say — and that
      // refusal names only the type.
      final attributed = _attributedBuildRefusal(
        error,
        stacktrace,
        owner: cm.simpleName,
        field: entry.key,
        declaredType: cm.instanceMembers[entry.key]!.reflectedReturnType,
        value: entry.value,
      );
      if (attributed == null) rethrow;
      throw attributed;
    } catch (error, stacktrace) {
      // The map in the field carries its own element type, and rejects a value
      // of the wrong one with a `_TypeError` naming two types and no field.
      // Declining on it would drop the entry; letting it travel bare would
      // report a failure the caller cannot attribute to anything in the
      // payload. Keep it, and say whose it is.
      throw TomReflectorException(
        "reflection.set.map_field_fill_failed",
        "Filling field '${entry.key}' of ${cm.simpleName} in place from "
            "${limited(entry.value, 100)} failed: $error",
        parameters: {"class": cm.simpleName, "field": entry.key},
        rootException: error,
        stack: stacktrace,
        autoLog: true,
      );
    }
    return true;
  }

  /// Attempts to create a new instance for the field and populate it.
  ///
  /// Used as a fallback when other map-setting strategies fail.
  bool _instantiateAndSetMapValue(
    InstanceMirror im,
    ClassMirror cm,
    MapEntry<String, dynamic> entry,
  ) {
    // The only two conditions that mean "not applicable" — no mirror for
    // the member, and a return type that names no class to build — are
    // decided by inspection rather than by catching. This is the last strategy
    // in the chain, so an error caught here would be the field's last chance
    // to report anything at all; a field this strategy declines is refused at
    // the end of [_setMapValue] instead of being left as it was.
    final returnType = cm.instanceMembers[entry.key]?.returnType;
    if (returnType is! ClassMirror) return false;

    // Declining is over: a class was named and this strategy is going to try
    // to build it. What is left can still fail, and the failure is not one the
    // caller can read on its own — the registry is keyed by declaration, so a
    // field declared `Box<int>` is built as `Box<dynamic>` and rejected by the
    // setter with a bare `_TypeError` naming two types and no field. Keep the
    // error and say whose it is.
    try {
      im.invokeSetter(
        entry.key,
        createInstanceFromJson(returnType, entry.value),
      );
    } on TomReflectorException catch (error, stacktrace) {
      final attributed = _attributedBuildRefusal(
        error,
        stacktrace,
        owner: cm.simpleName,
        field: entry.key,
        declaredType: cm.instanceMembers[entry.key]!.reflectedReturnType,
        value: entry.value,
      );
      if (attributed == null) rethrow;
      throw attributed;
    } catch (error, stacktrace) {
      throw TomReflectorException(
        "reflection.set.map_field_assignment_failed",
        "Built a ${returnType.simpleName} for map field '${entry.key}' of "
            "${cm.simpleName}, declared as ${cm.instanceMembers[entry.key]!.reflectedReturnType}, "
            "from ${limited(entry.value, 100)}, but the field would not take "
            "it: $error",
        parameters: {"class": cm.simpleName, "field": entry.key},
        rootException: error,
        stack: stacktrace,
        autoLog: true,
      );
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // List Value Setting
  // ---------------------------------------------------------------------------

  /// Sets a List value on a field.
  ///
  /// Handles multiple scenarios in order:
  /// 1. Primitive list types (`List<int>`, `List<String>`, etc.)
  /// 2. DateTime list types (`List<DateTime>`, etc.)
  /// 3. Annotated object list types (`List<MyClass>`)
  /// 4. Fallback: assign the list as it arrived, or refuse with
  ///    `reflection.set.list_field_not_settable` when the field cannot hold it
  void _setListValue(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final returnType = imGet.reflectedReturnType;

    // Try primitive list types
    if (_trySetPrimitiveListType(im, returnType, entry)) return;

    // Try DateTime list type
    if (_trySetDateTimeListType(im, cm, returnType, entry)) return;

    // Try annotated object list type
    if (_trySetAnnotatedObjectListType(im, cm, imGet, entry)) return;

    // Fallback: assign the list as it arrived. This is the last strategy in
    // the chain, so a failure here is the field's last chance to report
    // anything: absorbing it would make a list-shaped payload handed to a
    // field that cannot hold one look exactly like one that was applied.
    try {
      im.invokeSetter(entry.key, entry.value);
    } catch (error, stacktrace) {
      throw TomReflectorException(
        "reflection.set.list_field_not_settable",
        "No strategy could set list field '${entry.key}' of ${cm.simpleName}, "
            "declared as $returnType, from a ${entry.value.runtimeType} "
            "(${limited(entry.value, 100)}): $error",
        parameters: _fieldRefusalParameters(
          cm.simpleName,
          entry.key,
          returnType,
          entry.value,
        ),
        rootException: error,
        stack: stacktrace,
        autoLog: true,
      );
    }
  }

  /// Attempts to set a primitive List type using registered handlers.
  bool _trySetPrimitiveListType(
    InstanceMirror im,
    Type returnType,
    MapEntry<String, dynamic> entry,
  ) {
    final handler = _primitiveListTypeHandlers[returnType];
    if (handler != null) {
      handler(im, entry);
      return true;
    }
    return false;
  }

  /// Attempts to set a DateTime List type (`List<DateTime>`, etc.).
  bool _trySetDateTimeListType(
    InstanceMirror im,
    ClassMirror cm,
    Type returnType,
    MapEntry<String, dynamic> entry,
  ) {
    bool set<T>(T Function(String) parser, {bool nullable = false}) {
      im.invokeSetter(
        entry.key,
        _parseStringList<T>(
          entry,
          parser,
          owner: cm.simpleName,
          nullable: nullable,
        ),
      );
      return true;
    }

    if (returnType == List<DateTime>) {
      return set<DateTime>(DateTime.parse);
    }
    if (returnType == List<DateTime?>) {
      return set<DateTime?>(DateTime.parse, nullable: true);
    }
    if (returnType == List<TomZonedDate>) {
      return set<TomZonedDate>(TomZonedDate.parseFromString);
    }
    if (returnType == List<TomZonedDate?>) {
      return set<TomZonedDate?>(TomZonedDate.parseFromString, nullable: true);
    }
    if (returnType == List<TomZonedTime>) {
      return set<TomZonedTime>(TomZonedTime.parseFromString);
    }
    if (returnType == List<TomZonedTime?>) {
      return set<TomZonedTime?>(TomZonedTime.parseFromString, nullable: true);
    }
    if (returnType == List<TomZonedDateTime>) {
      return set<TomZonedDateTime>(TomZonedDateTime.parseFromString);
    }
    if (returnType == List<TomZonedDateTime?>) {
      return set<TomZonedDateTime?>(
        TomZonedDateTime.parseFromString,
        nullable: true,
      );
    }
    return false;
  }

  /// Parses a list of strings into typed datetime values.
  ///
  /// The result is built in full before the caller assigns it, so a single
  /// unparseable element leaves the target field holding its previous list.
  /// A parse failure names the field and the offending index rather than
  /// escaping as a bare [FormatException]; see [_parseDateTimeString].
  static List<T> _parseStringList<T>(
    MapEntry<String, dynamic> entry,
    T Function(String) parser, {
    required String owner,
    bool nullable = false,
  }) {
    final sourceList = entry.value as List<dynamic>;
    final result = <T>[];
    for (var index = 0; index < sourceList.length; index++) {
      final element = sourceList[index];
      if (element is String) {
        result.add(
          _parseDateTimeString<T>(
            element,
            parser,
            owner: owner,
            field: entry.key,
            targetType: T,
            at: 'index $index',
          ),
        );
      } else if (element == null && nullable) {
        result.add(null as T);
      } else {
        throw TomReflectorException(
          "reflection.set.datetime_must_be_filled_from_string_for_list",
          "Attempt to set datetime from non-String element $element",
          autoLog: true,
        );
      }
    }
    return result;
  }

  /// Attempts to set a List with annotated object elements.
  ///
  /// For `List<MyClass>` where MyClass is annotated with `@tomReflector`,
  /// this method creates instances of MyClass for each list element.
  ///
  /// **Important**: The target field must be initialized with an empty typed list.
  /// This method clears and populates the existing list rather than creating a new one.
  bool _trySetAnnotatedObjectListType(
    InstanceMirror im,
    ClassMirror cm,
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final typeString = imGet.reflectedReturnType.toString();
    if (!typeString.startsWith("List<")) return false;
    final memberMirror = imGet.returnType.typeArguments[0] as ClassMirror;

    // See the map counterpart: the caller has already established that the
    // value is a List, and `cast` checks nothing until the loop below reads an
    // element, so there is no failure here for a catch to absorb.
    final jsonList = (entry.value as List).cast<Map<String, dynamic>?>();

    // Materialize every element into a fresh list first; only assign on full
    // success so a mid-stream failure never leaves the field cleared-and-
    // truncated. An element rejected by the (non-nullable) target
    // type surfaces as a TomReflectorException instead of silent truncation.
    final newList = typeString.endsWith("?>")
        ? memberMirror.createNullableList()
        : memberMirror.createList();
    var building = 0;
    try {
      for (; building < jsonList.length; building++) {
        final subEntry = jsonList[building];
        newList.add(
          subEntry != null
              ? createInstanceFromJson(memberMirror, subEntry)
              : null,
        );
      }
    } on TomReflectorException catch (error, stacktrace) {
      final attributed = _attributedBuildRefusal(
        error,
        stacktrace,
        owner: cm.simpleName,
        field: entry.key,
        declaredType: imGet.reflectedReturnType,
        value: (entry.value as List)[building],
        at: 'index $building',
      );
      if (attributed == null) rethrow;
      throw attributed;
    } catch (error, stacktrace) {
      // See the map counterpart: a `List<List<X>>` field fails with a cast
      // error that names `List` and no reason. Say what is actually wrong.
      _throwIfNestedGeneric(imGet, entry.key, 0);
      throw TomReflectorException(
        "reflection.set.list_element_materialization_failed",
        "Failed to materialize element of list field '${entry.key}' "
            "(List<${memberMirror.simpleName}>): $error",
        parameters: {"key": entry.key},
        rootException: error,
        stack: stacktrace,
        autoLog: true,
      );
    }

    // Atomic assignment: only now that the whole list is built do we touch the
    // target field, preserving its prior content if anything above threw.
    final existingList = im.invokeGetter(entry.key) as List?;
    if (existingList == null) {
      im.invokeSetter(entry.key, newList);
    } else {
      existingList.clear();
      existingList.addAll(newList);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Value Getting Methods (Serialization)
  // ---------------------------------------------------------------------------

  /// Converts an object to a JSON string.
  ///
  /// This is the string-level outbound entry point, and the only one a
  /// transport needs: it is [getValues] plus encoding, extended to the two
  /// shapes JSON has natively.
  ///
  /// ## What [o] may be
  ///
  /// - **a `Map` or a `List`** — encoded as itself. Its elements are JSON
  ///   values already, except the complex ones, and each of those is rendered
  ///   by [getValues] with the full outbound precedence. Nesting is walked to
  ///   any depth.
  /// - **anything else** — rendered by [getValues], which is where the
  ///   precedence and the `@tomReflector` guard live. A bare `String` or `int`
  ///   is therefore still refused: it is not a container, and a caller handing
  ///   a scalar to a DTO serializer is not describing an object.
  ///
  /// Containers are the reason this method is not simply
  /// `jsonEncode(getValues(o))`. A handler that answers with a list of DTOs, or
  /// a map whose values are DTOs, has no reflected type of its own, so
  /// [getValues] refuses it — which left every transport to encode collections
  /// itself and, in the endpoint pipeline, to grow a parallel hook chain to do
  /// it with. Naming the container case once here is what lets those callers
  /// be one line.
  ///
  /// Example:
  /// ```dart
  /// final person = Person()
  ///   ..name = 'John'
  ///   ..age = 30;
  /// final json = tomReflectionInfo.convertToJsonString(person);
  /// // '{"name":"John","age":30}'
  ///
  /// tomReflectionInfo.convertToJsonString([person]);
  /// // '[{"name":"John","age":30}]'
  /// ```
  String convertToJsonString(Object o) {
    if (o is Map || o is List) {
      return jsonEncode(_renderJsonValue(o));
    }
    return jsonEncode(getValues(o));
  }

  /// Renders [value] into something `jsonEncode` accepts without a
  /// `toEncodable`.
  ///
  /// The containers are walked here rather than handed to `jsonEncode` with a
  /// `toEncodable` callback, because that callback's exceptions do not
  /// survive: `dart:convert` catches whatever it raises and rethrows a
  /// `JsonUnsupportedObjectError`, so the annotation guard's message — which
  /// names the type and says it is not annotated — would reach the caller as
  /// "converting object to an encodable object failed". Walking the container
  /// ourselves lets [getValues] throw its own exception, unwrapped.
  ///
  /// Complex values get exactly the [getValues] a top-level object would: an
  /// element is not serialized on easier terms than the object containing it,
  /// and the same guard applies to it. Nothing here reproduces the field
  /// walk's own conversions (dates, zoned times) — those belong to [getValues]
  /// and having a second copy of that table is how the two would drift.
  Object? _renderJsonValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, element) => MapEntry('$key', _renderJsonValue(element)),
      );
    }
    if (value is List) {
      return value.map(_renderJsonValue).toList();
    }
    return getValues(value);
  }

  /// Gets all values from an object as a JSON-compatible map.
  ///
  /// This is **the** outbound entry point: every way a Tom Core object reaches
  /// the wire passes through here, and every rendering hook the framework
  /// recognises is honoured here. A consumer therefore never needs a hook chain
  /// of its own — asking this method is the whole contract.
  ///
  /// ## Precedence
  ///
  /// The first match wins, and the order is deliberate rather than incidental:
  ///
  /// 1. **[TomClass]** — delegates to `TomClass.toJson()`. An `is` test.
  /// 2. **[TomJsonSerializable]** — delegates to its `toJson()`. Also an `is`
  ///    test, and settled *before any mirror work*, so a self-rendering type
  ///    need not be reflectable at all.
  /// 3. **a `toJson()` method** — the same rendering declared structurally
  ///    rather than nominally, found on the reflected type.
  /// 4. **a `jsonEncode` getter** — the kernel's own hook name.
  /// 5. **the reflected fields** — non-static, non-final, non-private.
  ///
  /// Why `toJson` outranks `jsonEncode`: steps 2 and 3 are the same method
  /// under two spellings, one nominal and one structural. Were `jsonEncode`
  /// placed between them, adding `implements TomJsonSerializable` to a class
  /// that happens to have both hooks would silently change its wire format —
  /// a declaration of intent would become a behavioural change. Ranking all
  /// three `toJson` forms together removes that trap.
  ///
  /// Steps 1 and 2 are `is` tests by design, not lookups: see
  /// [TomJsonSerializable] for why "this type serializes itself" is worth
  /// making a type-system fact rather than something to probe for.
  ///
  /// ## Supported Field Types
  ///
  /// - Primitive types: returned as-is
  /// - DateTime types: converted to ISO 8601 strings
  /// - TomZoned* types: converted to string representation
  /// - Nested objects: recursively converted via [getValues]
  /// - Collections: elements are recursively converted
  ///
  /// Example:
  /// ```dart
  /// final person = Person()
  ///   ..name = 'John'
  ///   ..age = 30
  ///   ..address = Address()..city = 'NYC';
  /// final values = tomReflectionInfo.getValues(person);
  /// // {'name': 'John', 'age': 30, 'address': {'city': 'NYC'}}
  /// ```
  Map<String, Object?> getValues(Object o) {
    if (o is TomClass) {
      return o.toJson();
    }

    // Ahead of `_reflect`, so a self-rendering DTO is never asked to be
    // reflectable. The interface exists to be cheap; consulting it after a
    // mirror round-trip would spend exactly what it was introduced to save,
    // and would make an unannotated one throw rather than serialize.
    if (o is TomJsonSerializable) {
      return o.toJson();
    }

    final im = _reflect(o, 'getValues');

    // Taken from the instance mirror rather than looked up again by
    // `reflectType(o.runtimeType)`: the registry is keyed by *declaration*, so
    // that lookup finds nothing for a generic value — `Box<int>` is not a key,
    // only `Box` is — and a generic class would be unserializable despite
    // being reflected. `im.type` is the mirror the instance itself resolved
    // to, so it is right for both, and there is no second lookup to disagree
    // with the first. Checked for the annotation on the way through: without
    // that, a quantified type walks zero declarations and returns `{}`.
    final classMirror = _annotatedType(im, o, 'getValues');

    final rendered = _tryInvokeToJson(im, classMirror, o);
    if (rendered != null) return rendered;

    final encoded = _tryGetJsonEncode(im, classMirror, o);
    if (encoded != null) return encoded;

    final result = <String, dynamic>{};
    final skippedFinals = <String>[];

    for (var d in classMirror.declarations.entries) {
      final dm = d.value;
      if (dm is! VariableMirror || dm.isStatic || dm.isPrivate) continue;
      if (dm.isFinal) {
        skippedFinals.add(d.key);
        continue;
      }
      _addFieldToResult(im, d.key, result);
    }

    if (result.isEmpty && skippedFinals.isNotEmpty) {
      throw _allFinalException(o, skippedFinals);
    }

    return result;
  }

  /// The exception raised when every wire member of a class was skipped for
  /// being `final`.
  ///
  /// `final` members are skipped because they cannot be restored: no
  /// reflective deserializer can assign one after construction, so emitting
  /// them would buy a payload that never round-trips — asymmetric in the
  /// direction that loses data quietly. That skip is not in question here.
  ///
  /// What is in question is the answer it produced. A class made entirely of
  /// `final` members walked every declaration, dropped every one, and returned
  /// `{}` reported as success: the same valid-looking payload with everything
  /// gone that [_notAnnotatedException] exists to prevent, reached by a
  /// different route. The silence is the defect, not the skip — an empty body
  /// with no diagnostic is what sends developers back to hand-written
  /// serializers, which is the outcome the reflective path exists to avoid.
  ///
  /// The condition is deliberately narrow: *nothing* was contributed **and**
  /// something was dropped. A class declaring no wire members at all still
  /// renders `{}`, because there `{}` is the truth; a class contributing even
  /// one field is left alone, because a caller can see which field survived
  /// and infer the rest. Only total, invisible loss is refused.
  ///
  /// This is not a ban on immutability. All four rendering hooks — [TomClass],
  /// [TomJsonSerializable], a structural `toJson()`, a `jsonEncode` getter —
  /// are consulted before the walk, so an immutable DTO that says how it
  /// renders never arrives here. The refusal asks for that decision to be
  /// made, not for the fields to be made mutable.
  static TomReflectorException _allFinalException(
    Object o,
    List<String> skipped,
  ) => TomReflectorException(
    "reflector.type.all_final",
    "TomReflectionInfo.getValues: every wire member of ${o.runtimeType} is "
        "final (${skipped.join(', ')}), so the reflective walk produced an "
        "empty object rather than a rendering; a final member is skipped "
        "because deserialization can never assign it back. Make the members "
        "non-final, or declare how the type renders itself — toJson(), a "
        "jsonEncode getter, TomJsonSerializable, or TomClass — all of which "
        "are honoured ahead of the walk",
    autoLog: true,
    parameters: {
      'type': o.runtimeType.toString(),
      'members': skipped.join(', '),
    },
  );

  /// Invokes the optional structural `toJson()` hook, if [cm] declares one.
  ///
  /// This is the same rendering [TomJsonSerializable] names nominally, reached
  /// for a type that has the method without declaring the interface. It is
  /// looked up rather than probed, and its failures are attributed, for the
  /// reasons given in [_hookFailed]; a hook returning the wrong shape is
  /// reported rather than skipped, as in [_tryGetJsonEncode].
  ///
  /// [TomClass] never arrives here — it declares `toJson()` too, and is
  /// answered by the `is` test at the top of [getValues] before any mirror is
  /// taken.
  Map<String, Object?>? _tryInvokeToJson(
    InstanceMirror im,
    ClassMirror cm,
    Object o,
  ) {
    if (!cm.instanceMembers.containsKey("toJson")) return null;

    final Object? rendered;
    try {
      rendered = im.invoke("toJson", []);
    } catch (error, stack) {
      throw _hookFailed('toJson', o.runtimeType, error, stack);
    }

    if (rendered is Map<String, Object?>) return rendered;
    throw _hookReturnedWrongType(
      'toJson',
      o.runtimeType,
      rendered,
      'Map<String, Object?>',
    );
  }

  /// Reads the optional `jsonEncode` hook, if [cm] declares one.
  ///
  /// Returns null only when there is no such hook. A hook that exists and
  /// raises propagates (see [_hookFailed]); one that returns something other
  /// than a JSON object is reported too, rather than ignored — the cast used
  /// to sit inside the same blanket catch, so a hook returning the wrong
  /// shape was read as no hook at all and the fields it exists to replace
  /// were serialized in its place.
  Map<String, Object?>? _tryGetJsonEncode(
    InstanceMirror im,
    ClassMirror cm,
    Object o,
  ) {
    if (!cm.instanceMembers.containsKey("jsonEncode")) return null;

    final Object? encoded;
    try {
      encoded = im.invokeGetter("jsonEncode");
    } catch (error, stack) {
      throw _hookFailed('jsonEncode', o.runtimeType, error, stack);
    }

    if (encoded is Map<String, Object?>) return encoded;
    throw _hookReturnedWrongType(
      'jsonEncode',
      o.runtimeType,
      encoded,
      'Map<String, Object?>',
    );
  }

  /// Adds a single field's value to the result map.
  void _addFieldToResult(
    InstanceMirror im,
    String fieldKey,
    Map<String, dynamic> result,
  ) {
    Object? sub;
    try {
      sub = im.invokeGetter(fieldKey);
    } catch (exception) {
      tomLog.warn("Failed to invoke $fieldKey $exception");
      return;
    }

    result[fieldKey] = _convertValueForJson(sub);
  }

  /// Converts a value to a JSON-compatible format.
  ///
  /// Handles primitives, DateTime types, Maps, Lists, and nested objects.
  ///
  /// **A temporal value crosses this wire naming its zone.** The `TomZoned*`
  /// types carry theirs in their own encoding; a bare [DateTime] cannot carry
  /// one in its type, so it is normalised to UTC here and written with the `Z`
  /// the reader needs. See the `DateTime` branch for why that is the whole
  /// convention rather than a preference.
  Object? _convertValueForJson(Object? value) {
    // Primitives and null
    if (value == null ||
        value is int ||
        value is double ||
        value is bool ||
        value is String) {
      return value;
    }

    // DateTime types - TomZoned* types must be checked before DateTime since they extend DateTime
    if (value is TomZonedDate) return value.toString();
    if (value is TomZonedTime) return value.toString();
    if (value is TomZonedDateTime) return value.toString();
    // `toUtc()` first, and this is the whole zone convention of the reflection
    // wire. `toIso8601String` emits the `Z` for a UTC instant and *no zone
    // marker at all* for a local one, and the read side parses the text with
    // `DateTime.parse`, which resolves a zoneless string against the *reading*
    // device. A local `DateTime` therefore did not merely arrive unconverted —
    // it arrived as a different instant, shifted by the offset between the two
    // machines, with nothing left in the payload to convert from. Invisible on
    // one host, which is why it survived.
    //
    // Normalising rather than inventing an encoding, because the three lines
    // above have already claimed every value that carries a zone of its own: a
    // value reaching here is a bare `DateTime`, which in Dart means an instant
    // and nothing else. UTC is that instant's unambiguous name, so the
    // conversion loses nothing — `isUtc` becomes true and the moment is
    // unchanged. A reader wanting wall-clock time calls `toLocal()`, which is
    // its own machine's question to ask and not the writer's to answer.
    if (value is DateTime) return value.toUtc().toIso8601String();

    // Maps - always convert to ensure nested DateTime values are serialized
    if (value is Map) {
      return _convertMapForJson(value);
    }

    // Lists
    if (value is List<String> ||
        value is List<int> ||
        value is List<double> ||
        value is List<bool>) {
      return value;
    }
    if (value is List || value is Iterable) {
      return _convertListForJson(value as Iterable);
    }

    // Complex objects - recursively convert
    return getValues(value);
  }

  /// Converts a Map to JSON-compatible format.
  ///
  /// Keys are converted to strings, values are recursively converted.
  Map<String, Object?> _convertMapForJson(Map map) {
    final tempMap = <String, Object?>{};
    for (var mapMember in map.entries) {
      tempMap[mapMember.key.toString()] = _convertValueForJson(mapMember.value);
    }
    return tempMap;
  }

  /// Converts a List/Iterable to JSON-compatible format.
  ///
  /// Each element is recursively converted.
  List<Object?> _convertListForJson(Iterable o) {
    final result = <Object?>[];
    for (var listElement in o) {
      result.add(_convertValueForJson(listElement));
    }
    return result;
  }
}

/// Global reflector instance for annotating classes.
///
/// Use this annotation on classes that need reflection support:
/// ```dart
/// @tomReflector
/// class MyClass {
///   String name = '';
///   int age = 0;
/// }
/// ```
///
/// After running `dart run build_runner build`, the class will be available
/// for reflection operations.
const TomReflector tomReflector = TomReflector();

/// Global reflection info instance.
///
/// Use this instance for all reflection operations:
/// ```dart
/// // Create instance
/// final person = tomReflectionInfo.createInstance<Person>();
///
/// // Set values from JSON
/// tomReflectionInfo.setValues(person, {'name': 'John', 'age': 30});
///
/// // Get values as JSON
/// final json = tomReflectionInfo.getValues(person);
/// ```
final TomReflectionInfo tomReflectionInfo = TomReflectionInfo();
