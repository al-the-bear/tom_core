// ignore_for_file: type_literal_in_constant_pattern

import 'dart:convert';

import 'package:tom_basics/tom_basics.dart';
import 'package:tom_reflection/tom_reflection.dart';
import '../little_things/exception_base.dart';
import '../timezoned/date_timestamp.dart';
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

  /// Creates a converter over the global [tomReflector].
  ///
  /// It takes no reflector, and that is not an omission — see the class
  /// documentation for why a second one cannot exist. Use the shared
  /// [tomReflectionInfo] instance in preference to constructing your own;
  /// the class carries no instance state at all.
  TomReflectionInfo();

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
    if (typeArguments.length < 2) {
      throw TomReflectorException(
        "reflector.type_resolution.not_a_map_type",
        "TomReflectionInfo.mapValueElementType: '${collection.runtimeType}' "
            "is not a Map<K, V> type (expected two type arguments)",
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
    return _resolveTypeArgument(
      typeArguments.first,
      collection,
      "singleElementType",
      "reflector.classmirror.not_found_for_iterable_value",
    );
  }

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
      final qualifiedNames = matches.map((m) => m.qualifiedName).join(", ");
      throw TomReflectorException(
        "reflector.classmirror.ambiguous_simple_name",
        "TomReflectionInfo._findClassMirror: simple name '$typeName' is "
            "ambiguous; it matches multiple annotated classes: $qualifiedNames",
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
  /// The three hooks — the `fromJson` constructor, the `jsonDecode` method and
  /// the `jsonEncode` getter — are all *optional*, and each used to be found
  /// by trying it inside an unqualified `catch`: whatever came out, the hook
  /// was declared missing and the ordinary field-walking path took over. That
  /// made a hook that does not exist and a hook that exists and is buggy the
  /// same event, and the second is the one worth hearing about — the caller's
  /// own code failed, and nothing said so. The failure was then attributed to
  /// the reflection layer, or to nothing at all.
  ///
  /// Each hook is now *looked up before it is called*, so absence is settled
  /// without running anything and the invocation itself is guarded only for
  /// the purpose of attribution. Nothing is inferred from the type of the
  /// failure, which matters because `tom_reflection` does not report
  /// absence in one consistent way: a missing constructor raises
  /// [NoSuchCapabilityError], but a missing method or getter surfaces as a
  /// plain `NoSuchMethodError` from a dynamic dispatch, because the generated
  /// getters map is shared across the whole reflector rather than per class.
  /// Catching by type would therefore have kept the two cases fused for two
  /// hooks out of three, and would additionally have re-fused them for any
  /// hook whose own body happens to raise either error.
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
  /// Returns the same object [o] with fields populated.
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
  /// This method first attempts to use a `fromJson` constructor if available.
  /// If not, it creates an instance using the default constructor and
  /// populates fields via [setValues].
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

    final Object? built;
    try {
      built = objectMirror.newInstance("fromJson", [jsonData]);
    } catch (error, stack) {
      throw _hookFailed('fromJson', objectMirror.simpleName, error, stack);
    }

    if (built is T) return built;
    throw _hookReturnedWrongType(
      'fromJson',
      objectMirror.simpleName,
      built,
      '$T',
    );
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
  /// This is the main entry point for deserialization. The method handles:
  ///
  /// - **TomClass objects**: Delegates to `TomClass.setValues()` for observable
  ///   field handling
  /// - **Objects with `jsonDecode` method**: Invokes that method directly
  /// - **Other objects**: Sets fields via reflection
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
  /// Returns the same object [o] with fields populated.
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

    if (_tryInvokeJsonDecode(im, cm, o, values)) {
      return o;
    }

    _logReflectionDetails(o, cm);

    for (var entry in values.entries) {
      _setFieldValue(im, cm, entry);
    }

    return o;
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
      _handleMissingField(imGet, entry);
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

  /// Handles cases where a field getter exists but no setter.
  ///
  /// This typically indicates a static, final, or private field.
  void _handleMissingField(
    MethodMirror? imGet,
    MapEntry<String, dynamic> entry,
  ) {
    if (imGet != null) {
      throw TomReflectorException(
        "reflection.set.unexpected_condition_final_static_private",
        "Unexpected condition in set values: $imGet ${entry.key} is ${entry.value} "
            "of type ${entry.value.runtimeType}, declaration is probably static, final or private.",
        autoLog: true,
      );
    } else {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "Found value/node ${entry.key} = ${entry.value} in values which do not correspond to declarations",
        );
      }
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
        "Unexpected type to set in set values: ${entry.key} is ${entry.value} of type ${entry.value.runtimeType}",
        autoLog: true,
      );
    }
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
    if (_trySetAnnotatedObjectMapType(im, imGet, entry)) return;

    // Try to fill existing object
    if (_tryFillExistingMapOrObject(im, entry)) return;

    // Try to instantiate and fill
    if (_instantiateAndSetMapValue(im, cm, entry)) return;

    if (debugSwitchLogReflectionDetailsValues) {
      tomLog.trace(
        "Could not set map value for field ${entry.key} of type $returnType",
      );
    }
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
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final typeString = imGet.reflectedReturnType.toString();
    if (!typeString.startsWith("Map<String,")) return false;
    final memberMirror = imGet.returnType.typeArguments[1] as ClassMirror;

    Map<String, Map<String, dynamic>?>? jsonMap;
    try {
      jsonMap = (entry.value as Map).cast<String, Map<String, dynamic>?>();
    } catch (e) {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "JSON value for map field ${entry.key} is not a Map<String, Map<String, dynamic>?>: ${entry.value.runtimeType}",
        );
      }
      return false;
    }

    // Materialize every value into a fresh map first; only assign on full
    // success so a mid-stream failure never leaves the field half-populated
    // (bug §48). A value rejected by the (non-nullable) target type surfaces
    // as a TomReflectorException instead of silently truncating the map.
    final newMap = typeString.endsWith("?>")
        ? memberMirror.createNullableValuedMap<String>()
        : memberMirror.createValuedMap<String>();
    try {
      for (var subEntry in jsonMap.entries) {
        newMap[subEntry.key] = subEntry.value != null
            ? createInstanceFromJson(memberMirror, subEntry.value!)
            : null;
      }
    } on TomReflectorException {
      rethrow;
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
    MapEntry<String, dynamic> entry,
  ) {
    try {
      final value = im.invokeGetter(entry.key);
      if (value == null || entry.value is! Map<String, dynamic>) return false;

      if (value is Map<String, Object?>) {
        for (var valueEntry in (entry.value as Map<String, dynamic>).entries) {
          value[valueEntry.key] = valueEntry.value;
        }
      } else {
        setValues(value, entry.value as Map<String, dynamic>);
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  /// Attempts to create a new instance for the field and populate it.
  ///
  /// Used as a fallback when other map-setting strategies fail.
  bool _instantiateAndSetMapValue(
    InstanceMirror im,
    ClassMirror cm,
    MapEntry<String, dynamic> entry,
  ) {
    final mm = cm.instanceMembers[entry.key];
    try {
      final pm = mm!.returnType as ClassMirror;
      final value = createInstanceFromJson(pm, entry.value);
      im.invokeSetter(entry.key, value);
      return true;
    } catch (error) {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "Could not instantiate and set map value for field ${entry.key} of type ${mm?.returnType}",
        );
      }
      return false;
    }
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
  /// 4. Fallback: direct value setting
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
    if (_trySetAnnotatedObjectListType(im, imGet, entry)) return;

    try {
      // Fallback: just try to set value
      im.invokeSetter(entry.key, entry.value);
    } catch (error) {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "Could not set list value for field ${entry.key} of type $returnType",
        );
      }
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
    MethodMirror imGet,
    MapEntry<String, dynamic> entry,
  ) {
    final typeString = imGet.reflectedReturnType.toString();
    if (!typeString.startsWith("List<")) return false;
    final memberMirror = imGet.returnType.typeArguments[0] as ClassMirror;

    List<Map<String, dynamic>?>? jsonList;
    try {
      jsonList = (entry.value as List).cast<Map<String, dynamic>?>();
    } catch (e) {
      if (debugSwitchLogReflectionDetailsValues) {
        tomLog.trace(
          "Value for list field ${entry.key} is not a List<Map<String, dynamic>?>: ${entry.value.runtimeType}",
        );
      }
      return false;
    }

    // Materialize every element into a fresh list first; only assign on full
    // success so a mid-stream failure never leaves the field cleared-and-
    // truncated (bug §48). An element rejected by the (non-nullable) target
    // type surfaces as a TomReflectorException instead of silent truncation.
    final newList = typeString.endsWith("?>")
        ? memberMirror.createNullableList()
        : memberMirror.createList();
    try {
      for (var subEntry in jsonList) {
        newList.add(
          subEntry != null
              ? createInstanceFromJson(memberMirror, subEntry)
              : null,
        );
      }
    } on TomReflectorException {
      rethrow;
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
  /// This is a convenience method that calls [getValues] and encodes the
  /// result to JSON.
  ///
  /// Example:
  /// ```dart
  /// final person = Person()
  ///   ..name = 'John'
  ///   ..age = 30;
  /// final json = tomReflectionInfo.convertToJsonString(person);
  /// // '{"name":"John","age":30}'
  /// ```
  String convertToJsonString(Object o) {
    return jsonEncode(getValues(o));
  }

  /// Gets all values from an object as a JSON-compatible map.
  ///
  /// This is the main entry point for serialization. The method handles:
  ///
  /// - **TomClass objects**: Delegates to `TomClass.toJson()`
  /// - **Objects with `jsonEncode` getter**: Uses that getter's result
  /// - **Other objects**: Extracts non-static, non-final, non-private fields via reflection
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

    final encoded = _tryGetJsonEncode(im, classMirror, o);
    if (encoded != null) return encoded;

    final result = <String, dynamic>{};

    for (var d in classMirror.declarations.entries) {
      final dm = d.value;
      if (dm is VariableMirror &&
          !dm.isStatic &&
          !dm.isFinal &&
          !dm.isPrivate) {
        _addFieldToResult(im, d.key, result);
      }
    }

    return result;
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
    if (value is DateTime) return value.toIso8601String();

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
