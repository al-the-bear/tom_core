import 'dart:convert';
import 'dart:math';

import 'package:tom_reflection/mirrors.dart';

import '../little_things/exception_base.dart';

import '../timezoned/date_timestamp.dart';
import 'tom_observable.dart';
export 'tom_observable.dart';

import '../reflection/reflection.dart';
export '../reflection/reflection.dart';

/// Exception thrown by observable objects when invalid operations are attempted.
///
/// This exception is used throughout the observable framework to indicate
/// errors such as:
/// - Attempting to set the entire value of a [TomClass], [TomList], or [TomMap]
/// - Invalid deserialization operations
/// - Type mismatches during value assignment
class TomObservableException extends TomException {
  TomObservableException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// A sentinel [TomObject] representing a null or unknown value.
///
/// Used as a return value when [TomObject._createFrom] cannot determine
/// the appropriate type for a given value.
TomObject<String> tomNull = TomObject<String>("tomNull");

/// A generic observable wrapper that holds a value of type [T].
///
/// [TomObject] is the foundation of the observable type system. It wraps
/// a value and provides:
/// - Automatic observer notification when the value changes
/// - Convenient operators for getting and setting values
/// - Support for adding observer callbacks
///
/// ## Operators
///
/// - `~obj` - Get the value (prefix operator)
/// - `obj()` - Get the value (call operator)
/// - `obj | newValue` - Set the value and notify observers
/// - `obj >> callback` - Add an observer callback function
///
/// ## Example
///
/// ```dart
/// final name = TomString("John");
///
/// // Subscribe to changes
/// name >> (obs) => print("Name changed to: ${~obs}");
///
/// // Set new value (triggers observer)
/// name | "Jane";
///
/// // Get value
/// print(~name); // "Jane"
/// print(name()); // "Jane"
/// ```
@tomReflector
class TomObject<T> extends TomObservable {
  /// Returns the runtime type [T] of this observable's value.
  Type getType() {
    return T;
  }

  /// Creates a new [TomObject] with the given initial value.
  TomObject(T initialValue) {
    _value = initialValue;
  }

  /// The internal value storage.
  late T _value;

  /// Returns the current value.
  T get() {
    return _value;
  }

  /// Sets the value and notifies observers if the value changed.
  /// Returns the new value.
  T set(T value) {
    if (value != _value) {
      _value = value;
      notifyObservers();
    }
    return _value;
  }

  /// Returns the value, or `null` if the value itself is null.
  /// Useful for nullable TomObject types.
  T? getOrNull() {
    return _value;
  }

  /// Returns `true` if the current value is `null`.
  bool get isNull => _value == null;

  /// Prefix operator to get the value: `~myObject`
  T operator ~() {
    return get();
  }

  /// Call operator to get the value: `myObject()`
  T call() {
    return get();
  }

  /// Pipe operator to set the value: `myObject | newValue`
  T operator |(T value) {
    return set(value);
  }

  /// Left shift operator to set the value: `myObject << newValue`
  TomObject<T> operator <<(T value) {
    set(value);
    return this;
  }

  /// Creates a [TomObject] wrapper from a dynamic value.
  ///
  /// Automatically determines the appropriate [TomObject] subtype based on
  /// the runtime type of [v]:
  /// - [String] → [TomString] (or timezone types if prefixed)
  /// - [DateTime] → [TomDateTime]
  /// - [int] → [TomInt]
  /// - [bool] → [TomBool]
  /// - [Map] → [TomMap] (recursively wraps values)
  /// - [List] → [TomList] (recursively wraps elements)
  ///
  /// Returns [tomNull] if the type cannot be determined.
  static TomObject _createFrom(dynamic v) {
    if (v is String) {
      if (v.startsWith(TomDateTime.serializationPrefix)) {
        return TomDateTime(DateTime.parse(v.substring(3)));
      } else if (v.startsWith(TomZonedDate.serializationPrefix)) {
        return TomOZonedDate(TomZonedDate.parseFromString(v));
      }
      if (v.startsWith(TomZonedTime.serializationPrefix)) {
        return TomOZonedTime(TomZonedTime.parseFromString(v));
      }
      if (v.startsWith(TomZonedDateTime.serializationPrefix)) {
        return TomOZonedDateTime(TomZonedDateTime.parseFromString(v));
      }
      return TomString(v);
    }
    if (v is DateTime) {
      return TomDateTime(v);
    }
    if (v is int) {
      return TomInt(v);
    }
    if (v is bool) {
      return TomBool(v);
    }
    if (v is Map) {
      TomMap result = TomMap();
      for (var key in v.keys) {
        result[key] = _createFrom(v[key]);
      }
      return result;
    }
    if (v is List) {
      TomList result = TomList();
      for (var element in v) {
        result.add(_createFrom(element));
      }
      return result;
    }
    return tomNull;
  }

  @override
  String toString() {
    return "~$_value";
  }
}

/// An observable wrapper for [String] values.
///
/// Provides all [TomObject] functionality for string values.
///
/// Example:
/// ```dart
/// final name = TomString("Hello");
/// name | "World"; // Set new value
/// print(~name); // "World"
/// ```
@tomReflector
class TomString extends TomObject<String> {
  /// Creates a new observable string with the given initial value.
  TomString(super.initialValue);
}

/// An observable wrapper for [int] values.
///
/// Provides all [TomObject] functionality for integer values.
///
/// Example:
/// ```dart
/// final count = TomInt(0);
/// count | 42; // Set new value
/// print(~count); // 42
/// ```
@tomReflector
class TomInt extends TomObject<int> {
  /// Creates a new observable integer with the given initial value.
  TomInt(super.initialValue);
}

/// An observable wrapper for [double] values.
///
/// Provides all [TomObject] functionality for double-precision floating point values.
///
/// Example:
/// ```dart
/// final price = TomDouble(19.99);
/// price | 24.99; // Set new value
/// print(~price); // 24.99
/// ```
@tomReflector
class TomDouble extends TomObject<double> {
  /// Creates a new observable double with the given initial value.
  TomDouble(super.initialValue);
}

/// An observable wrapper for [bool] values.
///
/// Provides all [TomObject] functionality for boolean values.
///
/// Example:
/// ```dart
/// final isActive = TomBool(false);
/// isActive | true; // Set new value
/// print(~isActive); // true
/// ```
@tomReflector
class TomBool extends TomObject<bool> {
  /// Creates a new observable boolean with the given initial value.
  TomBool(super.initialValue);
}

/// An observable wrapper for [DateTime] values.
///
/// Provides all [TomObject] functionality for DateTime values.
/// Uses a special serialization prefix for JSON serialization.
///
/// Example:
/// ```dart
/// final createdAt = TomDateTime(DateTime.now());
/// createdAt | DateTime.utc(2024, 1, 1); // Set new value
/// ```
@tomReflector
class TomDateTime extends TomObject<DateTime> {
  /// A sentinel value representing "no date" (Unix epoch in UTC).
  static final TomDateTime noDateTime = TomDateTime(DateTime.utc(1970));

  /// The prefix used for serializing [TomDateTime] values to strings.
  static const String serializationPrefix = "@!@";

  /// Creates a new observable DateTime with the given initial value.
  TomDateTime(super.initialValue);
}

/// An observable wrapper for [TomTimezoned] values (timezone-aware date/time).
///
/// This is the base class for timezone-aware observable types:
/// - [TomOZonedTime] - time with timezone
/// - [TomOZonedDate] - date with timezone
/// - [TomOZonedDateTime] - datetime with timezone
///
/// Subclasses override [setByString] and [getSerializationPrefix] for
/// proper serialization/deserialization.
@tomReflector
class TomOTimezoned<TZ extends TomTimezoned?> extends TomObject<TZ> {
  /// Returns the serialization prefix for this timezone type.
  /// Override in subclasses to return the appropriate prefix.
  String getSerializationPrefix() {
    return TomZonedDateTime.serializationPrefix;
  }

  /// Sets the value by parsing a serialized string representation.
  /// Override in subclasses to handle the specific timezone type.
  void setByString(String s) {}

  /// A sentinel value representing "no datetime" (Unix epoch in UTC).
  static final TomOTimezoned noDateTime = TomOTimezoned._(
    TomTimezoned.fromDateTime(DateTime.utc(1970)),
  );

  /// Creates a new observable timezone-aware value with the given initial value.
  TomOTimezoned._(super.initialValue);
}

/// An observable wrapper for [TomZonedTime] values (time with timezone).
///
/// Supports serialization with the [TomZonedTime.serializationPrefix] (`@T@`).
///
/// Example:
/// ```dart
/// final meetingTime = TomOZonedTime(TomZonedTime.now());
/// ```
@tomReflector
class TomOZonedTime extends TomOTimezoned<TomZonedTime> {
  /// A sentinel value representing "no time" (Unix epoch).
  static final TomZonedTime noZonedTime = TomZonedTime.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedTime.serializationPrefix)) {
      if (s.length > TomZonedTime.serializationPrefix.length) {
        set(TomZonedTime.parseFromString(s));
      } else {
        set(noZonedTime);
      }
    } else {
      set(TomZonedTime.fromDateTime(DateTime.parse(s)));
    }
  }

  @override
  String getSerializationPrefix() {
    return TomZonedTime.serializationPrefix;
  }

  static final TomOZonedTime noTime = TomOZonedTime(
    TomZonedTime.fromDateTime(DateTime.utc(1970)),
  );

  TomOZonedTime(super.initialValue) : super._();
}

/// An observable wrapper for [TomZonedDate] values (date with timezone).
///
/// Supports serialization with the [TomZonedDate.serializationPrefix] (`@D@`).
///
/// Example:
/// ```dart
/// final birthDate = TomOZonedDate(TomZonedDate.now());
/// ```
@tomReflector
class TomOZonedDate extends TomOTimezoned<TomZonedDate> {
  /// A sentinel value representing "no date" (Unix epoch).
  static final TomZonedDate noZonedDate = TomZonedDate.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedDate.serializationPrefix)) {
      if (s.length > TomZonedDate.serializationPrefix.length) {
        set(TomZonedDate.parseFromString(s));
      } else {
        set(noZonedDate);
      }
    } else {
      set(TomZonedDate.fromDateTime(DateTime.parse(s)));
    }
  }

  @override
  String getSerializationPrefix() {
    return TomZonedDate.serializationPrefix;
  }

  static final TomOZonedDate noTime = TomOZonedDate(
    TomZonedDate.fromDateTime(DateTime.utc(1970)),
  );

  TomOZonedDate(super.initialValue): super._();
}

/// An observable wrapper for [TomZonedDateTime] values (datetime with timezone).
///
/// Supports serialization with the [TomZonedDateTime.serializationPrefix] (`@X@`).
///
/// Example:
/// ```dart
/// final eventTime = TomOZonedDateTime(TomZonedDateTime.fromDateTime(DateTime.now()));
/// ```
@tomReflector
class TomOZonedDateTime extends TomOTimezoned<TomZonedDateTime> {
  /// A sentinel value representing "no datetime" (Unix epoch).
  static final TomZonedDateTime noZonedDateTime = TomZonedDateTime.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedDateTime.serializationPrefix)) {
      if (s.length > TomZonedDateTime.serializationPrefix.length) {
        set(TomZonedDateTime.parseFromString(s));
      } else {
        set(noZonedDateTime);
      }
    } else {
      set(TomZonedDateTime.fromDateTime(DateTime.parse(s)));
    }
  }

  static final TomOZonedDateTime noTime = TomOZonedDateTime(
    TomZonedDateTime.fromDateTime(DateTime.utc(1970)),
  );

  TomOZonedDateTime(super.initialValue): super._();
}

/// An observable wrapper for nullable [String] values.
///
/// Like [TomString] but allows `null` values.
///
/// Example:
/// ```dart
/// final nickname = TomNString(null);
/// if (nickname.isNull) print("No nickname set");
/// nickname | "Johnny"; // Set a value
/// ```
@tomReflector
class TomNString extends TomObject<String?> {
  /// Creates a new observable nullable string with the given initial value.
  TomNString(super.initialValue);
}

/// An observable wrapper for nullable [int] values.
///
/// Like [TomInt] but allows `null` values.
@tomReflector
class TomNInt extends TomObject<int?> {
  /// Creates a new observable nullable integer with the given initial value.
  TomNInt(super.initialValue);
}

/// An observable wrapper for nullable [double] values.
///
/// Like [TomDouble] but allows `null` values.
@tomReflector
class TomNDouble extends TomObject<double?> {
  /// Creates a new observable nullable double with the given initial value.
  TomNDouble(super.initialValue);
}

/// An observable wrapper for nullable [bool] values.
///
/// Like [TomBool] but allows `null` values.
@tomReflector
class TomNBool extends TomObject<bool?> {
  /// Creates a new observable nullable boolean with the given initial value.
  TomNBool(super.initialValue);
}

/// An observable wrapper for nullable [DateTime] values.
///
/// Like [TomDateTime] but allows `null` values.
@tomReflector
class TomNDateTime extends TomObject<DateTime?> {
  /// A sentinel value representing "no date" (Unix epoch in UTC).
  static final TomDateTime noDateTime = TomDateTime(DateTime.utc(1970));

  /// The prefix used for serializing [TomNDateTime] values to strings.
  static const String serializationPrefix = TomDateTime.serializationPrefix;

  /// Creates a new observable nullable DateTime with the given initial value.
  TomNDateTime(super.initialValue);
}

/// An observable wrapper for nullable [TomTimezoned] values.
///
/// This is the base class for nullable timezone-aware observable types:
/// - [TomNOZonedTime] - nullable time with timezone
/// - [TomNOZonedDate] - nullable date with timezone
/// - [TomNOZonedDateTime] - nullable datetime with timezone
@tomReflector
class TomNOTimezoned<TZ extends TomTimezoned?> extends TomOTimezoned<TZ> {
  /// A sentinel value representing "no datetime" (Unix epoch in UTC).
  static final TomNOTimezoned noDateTime = TomNOTimezoned._(
    TomTimezoned.fromDateTime(DateTime.utc(1970)),
  );

  /// Creates a new observable nullable timezone-aware value.
  TomNOTimezoned._(super.initialValue) : super._();
}

/// An observable wrapper for nullable [TomZonedTime] values.
///
/// Like [TomOZonedTime] but allows `null` values. When serialized with an
/// empty value after the prefix, deserializes to `null`.
@tomReflector
class TomNOZonedTime extends TomNOTimezoned<TomZonedTime?> {
  /// A sentinel value representing "no time" (Unix epoch).
  static final TomZonedTime noZonedTime = TomZonedTime.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedTime.serializationPrefix)) {
      if (s.length > TomZonedTime.serializationPrefix.length) {
        set(TomZonedTime.parseFromString(s));
      } else {
        set(null);
      }
    } else {
      set(TomZonedTime.fromDateTime(DateTime.parse(s)));
    }
  }

  @override
  String getSerializationPrefix() {
    return TomZonedTime.serializationPrefix;
  }

  static final TomNOZonedTime noTime = TomNOZonedTime(
    TomZonedTime.fromDateTime(DateTime.utc(1970)),
  );

  TomNOZonedTime(super.initialValue) : super._();
}

/// An observable wrapper for nullable [TomZonedDate] values.
///
/// Like [TomOZonedDate] but allows `null` values. When serialized with an
/// empty value after the prefix, deserializes to `null`.
@tomReflector
class TomNOZonedDate extends TomNOTimezoned<TomZonedDate?> {
  /// A sentinel value representing "no date" (Unix epoch).
  static final TomZonedDate noZonedDate = TomZonedDate.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedDate.serializationPrefix)) {
      if (s.length > TomZonedDate.serializationPrefix.length) {
        set(TomZonedDate.parseFromString(s));
      } else {
        set(null);
      }
    } else {
      set(TomZonedDate.fromDateTime(DateTime.parse(s)));
    }
  }

  @override
  String getSerializationPrefix() {
    return TomZonedDate.serializationPrefix;
  }

  static final TomNOZonedDate noTime = TomNOZonedDate(
    TomZonedDate.fromDateTime(DateTime.utc(1970)),
  );

  TomNOZonedDate(super.initialValue) : super._();
}

/// An observable wrapper for nullable [TomZonedDateTime] values.
///
/// Like [TomOZonedDateTime] but allows `null` values. When serialized with an
/// empty value after the prefix, deserializes to `null`.
@tomReflector
class TomNOZonedDateTime extends TomNOTimezoned<TomZonedDateTime?> {
  /// A sentinel value representing "no datetime" (Unix epoch).
  static final TomZonedDateTime noZonedDateTime = TomZonedDateTime.fromDateTime(
    DateTime(1970),
  );

  @override
  void setByString(String s) {
    if (s.startsWith(TomZonedDateTime.serializationPrefix)) {
      if (s.length > TomZonedDateTime.serializationPrefix.length) {
        set(TomZonedDateTime.parseFromString(s));
      } else {
        set(null);
      }
    } else {
      set(TomZonedDateTime.fromDateTime(DateTime.parse(s)));
    }
  }

  static final TomNOZonedDateTime noTime = TomNOZonedDateTime(
    TomZonedDateTime.fromDateTime(DateTime.utc(1970)),
  );

  TomNOZonedDateTime(super.initialValue) : super._();
}

/// An observable date range with start and end dates.
///
/// Both dates are nullable [TomNOZonedDate] values, allowing open-ended ranges.
///
/// Example:
/// ```dart
/// final vacation = TomDateRange();
/// vacation.startDate | TomZonedDate.now();
/// vacation.endDate | TomZonedDate.now().add(Duration(days: 7));
/// ```
@tomReflector
class TomDateRange extends TomClass {
  /// The start date of the range (nullable).
  TomNOZonedDate startDate = TomNOZonedDate(TomNOZonedDate.noZonedDate);

  /// The end date of the range (nullable).
  TomNOZonedDate endDate = TomNOZonedDate(TomNOZonedDate.noZonedDate);
}

/// An observable time range with start and end times.
///
/// Both times are nullable [TomNOZonedTime] values, allowing open-ended ranges.
@tomReflector
class TomTimeRange extends TomClass {
  /// The start time of the range (nullable).
  TomNOZonedTime startTime = TomNOZonedTime(TomNOZonedTime.noZonedTime);

  /// The end time of the range (nullable).
  TomNOZonedTime endTime = TomNOZonedTime(TomNOZonedTime.noZonedTime);
}

/// An observable datetime range with start and end datetimes.
///
/// Both datetimes are nullable [TomNOZonedDateTime] values, allowing open-ended ranges.
@tomReflector
class TomDateTimeRange extends TomClass {
  /// The start datetime of the range (nullable).
  TomNOZonedDateTime startDateTime = TomNOZonedDateTime(TomNOZonedDateTime.noZonedDateTime);

  /// The end datetime of the range (nullable).
  TomNOZonedDateTime endDateTime = TomNOZonedDateTime(TomNOZonedDateTime.noZonedDateTime);
}

/// A base class for complex observable objects with multiple [TomObject] members.
///
/// [TomClass] automatically registers all [TomObject] fields as observable
/// members using reflection. When any member changes, the parent [TomClass]
/// is notified and propagates the notification to its own observers.
///
/// ## Features
///
/// - **Automatic member registration**: Fields are discovered via reflection
/// - **Cascading observation**: Changes to any member notify the parent
/// - **JSON serialization**: Built-in [toJson] and [fromJson] support
/// - **Batch updates**: [setValues] for updating multiple fields at once
/// - **Muting**: Temporarily suppress notifications during bulk updates
///
/// ## Example
///
/// ```dart
/// @tomReflector
/// class Person extends TomClass {
///   final name = TomString("");
///   final age = TomInt(0);
///   final email = TomNString(null);
/// }
///
/// final person = Person();
/// person.name | "John";
/// person.setValues({"age": 30, "email": "john@example.com"});
/// print(person.toJson());
/// ```
@tomReflector
class TomClass extends TomObject<Map<String, TomObject>>
    implements TomObserver<TomObject> {
  /// Creates a new [TomClass] and automatically registers all [TomObject]
  /// members for observation.
  TomClass() : super({}) {
    prepareForSelfObservation();
    startSelfObservation();
  }

  static final ClassMirror _classMirror =
      tomReflector.reflectType(TomClass) as ClassMirror;

  /// Hook to create objects BEFORE start of self-observation
  /// 
  void prepareForSelfObservation() {
    // Override in subclasses to create member objects before observation starts
  }

  /// Throws [TomObservableException] - direct value setting is not allowed.
  ///
  /// Use [setValues] to update multiple fields, or set individual member
  /// fields directly using their `|` operator.
  @override
  Map<String, TomObject> set(Map<String, TomObject> value) {
    throw TomObservableException(
      "TomClass.state_error.set_not_allowed",
      "You can't set the value of TomClass, you can only set individuals fields",
    );
  }

  /// Throws [TomObservableException] - direct value getting is not allowed.
  ///
  /// Use [getValues] to get all values as a Map, or access individual
  /// member fields directly.
  @override
  Map<String, TomObject> get() {
    throw TomObservableException(
      "TomClass.state_error.get_not_allowed",
      "You can't get the value of TomClass, you can only get individuals fields",
    );
  }

  @override
  TomClass operator <<(Map<String, dynamic> value) {
    throw TomObservableException(
      "TomClass.state_error.set_not_allowed",
      "You can't set the value of TomClass, you can only set individuals fields",
    );
  }

  /// Initializes observation of all [TomObject] members.
  ///
  /// This method uses reflection to discover all [TomObject] fields and
  /// registers this [TomClass] as an observer on each one. Called automatically
  /// by the constructor.
  void startSelfObservation() {
    TomReflector r = tomReflector;
    var classMirror = r.reflectType(runtimeType) as ClassMirror;
    var instanceMirror = r.reflect(this);
    _registerWithMembers(classMirror, instanceMirror);
  }

  void _registerWithMembers(ClassMirror cm, InstanceMirror im) {
    cm.declarations.forEach((key, value) {
      for (var member in cm.instanceMembers.values) {
        if (member.simpleName == value.simpleName && member.isGetter) {
          Object? value = im.invokeGetter(member.simpleName);
          if (value != null && value is TomObservable) {
            //print("Registering on ${member.simpleName}");
            value.addObserver(this);
            if (value is TomObject) {
              _value[member.simpleName] = value;
            }
          }
        }
      }
    });
    try {
      if (cm.superclass != null) {
        _registerWithMembers(cm.superclass!, im);
      }
    } catch (e, s) {
      throw TomObservableException(
        "TomClass.initialization_error.could_not_register_superclass_members",
        "Failure during TomClass superclass member registration for observable notifications",
        rootException: e,
        stack: s,
      );
    }
  }

  /// Returns a map of all registered [TomObject] members.
  ///
  /// Keys are the field names, values are the [TomObject] instances.
  Map<String, TomObject> getMembers() {
    return _value;
  }

  /// Called when any observed member changes.
  ///
  /// Propagates the notification to this [TomClass]'s own observers.
  @override
  void onNotify(TomObservable observable) {
    notifyObservers();
  }

  /// Mutes this [TomClass] and all its members.
  ///
  /// While muted, changes to any member will not trigger notifications.
  /// Call [unmute] to resume notifications.
  @override
  void mute() {
    super.mute();
    for (var key in _value.keys) {
      TomObject? member = _value[key];
      if (member != null) {
        member.mute();
      }
    }
  }

  /// Unmutes this [TomClass] and all its members.
  ///
  /// If changes occurred while muted, observers will be notified once.
  /// Members are unmuted first (while parent is still muted) so their
  /// notifications just mark the parent as dirty, then the parent is
  /// unmuted for a single consolidated notification.
  @override
  void unmute() {
    // First unmute all members while parent is still muted.
    // If members notify, the parent's onNotify will just mark it as dirty.
    for (var key in _value.keys) {
      TomObject? member = _value[key];
      if (member != null) {
        member.unmute();
      }
    }
    // Then unmute parent - will notify once if any member was dirty
    super.unmute();
  }

  /// Updates multiple member fields from a map of values.
  ///
  /// Keys should match field names. For [TomList] and [TomMap] members,
  /// existing values are cleared before setting new ones.
  ///
  /// Example:
  /// ```dart
  /// person.setValues({"name": "John", "age": 30});
  /// ```
  void setValues(Map<String, dynamic> values) {
    setOrMergeValues(values, false);
  }

  /// Updates or merges multiple member fields from a map of values.
  ///
  /// When [merge] is `true`, [TomList] and [TomMap] members will have values
  /// added to them rather than being cleared first.
  ///
  /// When [merge] is `false`, collections are cleared before new values
  /// are added (same behavior as [setValues]).
  void setOrMergeValues(Map<String, dynamic> values, bool merge) {
    mute();
    for (var key in values.keys) {
      TomObject? member = _value[key] ?? _value["_$key"];
      var value = values[key];
      if (member != null) {
        if (member is TomClass) {
          member.setOrMergeValues(value, merge);
        } else {
          if (member is TomList) {
            _setListMember(member, value, key, !merge);
          } else if (member is TomMap) {
            _setMapMember(member, value, key, !merge);
          } else {
            if (member is TomDateTime && value is String) {
              if (value.startsWith(TomDateTime.serializationPrefix)) {
                member.set(DateTime.parse(value.substring(3)));
              } else {
                member.set(DateTime.parse(value));
              }
            } else if (member is TomOTimezoned && value is String) {
              member.setByString(value);
            } else {
              member.set(value);
            }
          }
        }
      }
    }
    unmute();
  }

  void _setMapMember(
    TomMap<dynamic, TomObject<dynamic>> member,
    value,
    String key,
    bool clear,
  ) {
    if (clear) {
      member.clear();
    }
    if (value is Map) {
      var memberMirror = tomReflectionInfo.mapValueElementType(member);
      for (var key in value.keys) {
        var element = value[key];
        if (memberMirror.isAssignableTo(TomClass._classMirror)) {
          var obj = memberMirror.newInstance("", []);
          if (obj is TomClass) {
            if (element is Map<String, dynamic>) {
              obj.setValues(element);
            } else {
              throw TomObservableException(
                "TomClass.set_map_member_error.invalid_element_type",
                "TomClass elements of type ${memberMirror.simpleName} must be deserialized from Map objects but found ${element.runtimeType}",
              );
            }
          } else {
            throw TomObservableException(
              "TomClass.set_map_member_error.invalid_list_type",
              "Only lists with TomObject or TomClass types are allowed. Found ${obj.runtimeType}",
            );
          }
          member[key] = obj;
        } else {
          member[key] = TomObject._createFrom(element);
        }
      }
    } else {
      throw TomObservableException(
        "TomClass.set_map_member_error.not_a_map",
        "TomMap member $key must be deserialized from a Map, but got ${value.runtimeType}",
      );
    }
  }

  void _setListMember(
    TomList<TomObject<dynamic>> member,
    value,
    String key,
    bool clear,
  ) {
    if (clear) {
      member.clear();
    }
    var memberMirror = tomReflectionInfo.singleElementType(member);
    if (value is List) {
      for (var element in value) {
        //tomReflectionInfo.reflect(memberMirror);
        if (memberMirror.isAssignableTo(TomClass._classMirror)) {
          var obj = memberMirror.newInstance("", []);
          if (obj is TomClass) {
            if (element is Map<String, dynamic>) {
              obj.setValues(element);
            } else {
              throw TomObservableException(
                "TomClass.set_list_member_error.not_a_map",
                "TomClass elements of type ${memberMirror.simpleName} must be deserialized from Map objects but found ${element.runtimeType}",
              );
            }
          } else {
            throw TomObservableException(
              "TomClass.set_list_member_error.invalid_list_type",
              "Only lists with TomObject or TomClass types are allowed. Found ${obj.runtimeType}",
            );
          }
          member.add(obj);
        } else {
          member.add(TomObject._createFrom(element));
        }
      }
    } else {
      throw TomObservableException(
        "TomClass.set_list_member_error.not_a_list",
        "TomList member $key must get deserialized from a list, but ${value.runtimeType} ",
      );
    }
  }

  /// Returns all member values as a map.
  ///
  /// The returned map can be used for JSON serialization. Nested [TomClass]
  /// instances are recursively converted. DateTime and timezone values are
  /// serialized with their appropriate prefixes.
  Map<String, dynamic> getValues() {
    Map<String, Object?> result = {};
    try {
      for (var key in _value.keys) {
        var value = _value[key]!;
        // Check if it's a TomClass BEFORE calling .get() since TomClass.get() throws
        if (value is TomClass) {
          result[key] = (value).getValues();
        } else {
          var valueValue = value.get();
          // TODO: add serialization/deserialization for other DateTime-derived classes
          if (value is TomDateTime || value is TomNDateTime) {
            result[key] =
                valueValue !=
                "${TomDateTime.serializationPrefix}${valueValue == null ? '' : valueValue.toString()}";
          } else if (value is TomOTimezoned) {
            result[key] = valueValue != null
                ? valueValue.toString()
                : value.getSerializationPrefix();
          } else {
            result[key] = valueValue;
          }
        }
      }
    } catch (exception, stacktrace) {
      print("Failed $exception at $stacktrace");
    }
    //print("getValues: $result");
    return result;
  }

  /// Populates this [TomClass] from a JSON string.
  ///
  /// Parses the JSON and calls [setValues] with the resulting map.
  void fromJson(String json) {
    setValues(jsonDecode(json));
  }

  /// Converts this [TomClass] to a JSON-compatible map.
  ///
  /// Equivalent to calling [getValues].
  Map<String, dynamic> toJson() {
    return getValues();
  }

  /// Returns a string representation using reflection to get all values.
  @override
  String toString() {
    return tomReflectionInfo.getValues(this).toString();
  }
}

/// An observable list that automatically observes all contained elements.
///
/// [TomList] wraps a [List] of [TomObject] elements and provides:
/// - Automatic observation of all elements (changes in elements notify the list)
/// - All standard [List] operations with observer management
/// - Custom operators for convenient element manipulation
///
/// ## Methods
///
/// - `list.append(element)` - Add an element (returns the list for chaining)
/// - `list[index]` - Get element at index
/// - `list[index] = value` - Set element at index
/// - `list + other` - Concatenate two TomLists
///
/// ## Example
///
/// ```dart
/// final items = TomList<TomString>();
/// items.append(TomString(\"first\"));
/// items.append(TomString(\"second\"));
///
/// items >> (obs) => print(\"List changed!\");
/// items[0] | \"updated\"; // Triggers observer
/// ```
@tomReflector
class TomList<E extends TomObject> extends TomObject<List<E>>
    implements TomObserver, Iterable {
  // ignore: prefer_final_fields
  bool _serializing = false;

  /// Creates an empty observable list.
  TomList() : super(List<E>.empty(growable: true));

  /// Creates an observable list from an existing [TomList].
  ///
  /// Elements are copied and observed.
  TomList.from(TomList<E> existing)
    : super(List<E>.from(existing._value, growable: true)) {
    _attachTo(_value);
  }

  /// Creates an observable list as a copy of an existing [TomList].
  ///
  /// Elements are copied and observed.
  TomList.of(TomList<E> existing)
    : super(List<E>.of(existing._value, growable: true)) {
    _attachTo(_value);
  }

  /// Creates an observable list from an existing standard [List].
  ///
  /// All elements in the list are observed.
  TomList.ofList(List<E> list) : super(list) {
    _attachTo(list);
  }

  void _attachTo(Iterable<E> list) {
    for (var e in list) {
      e.addObserver(this);
    }
  }

  bool _detachFrom(Iterable<E> list) {
    bool didDetach = false;
    for (var e in list) {
      e.removeObserver(this);
      didDetach = true;
    }
    return didDetach;
  }

  /// Throws [TomObservableException] unless called during serialization.
  ///
  /// Use [add], [addAll], or index assignment to modify the list.
  @override
  List<E> set(List<E> value) {
    if (!_serializing) {
      throw TomObservableException(
        "TomClass.tomlist_state_error.set_not_allowed",
        "You can't set the value of TomList, you can only set individuals elements",
      );
    }
    _value = value;
    return _value;
  }

  /// Returns a copy of the internal list.
  @override
  List<E> get() {
    return _value.toList(growable: true);
  }

  /// Called when any observed element changes.
  ///
  /// Propagates the notification to this list's observers.
  @override
  void onNotify(TomObservable observable) {
    notifyObservers();
  }

  /// Mutes this list and all its elements.
  ///
  /// While muted, changes to elements are tracked but not propagated.
  /// Call [unmute] to resume notifications and trigger a single
  /// consolidated notification if any elements were modified.
  @override
  void mute() {
    super.mute();
    for (var element in _value) {
      element.mute();
    }
  }

  /// Unmutes this list and all its elements.
  ///
  /// Elements are unmuted first while the list is still muted, so their
  /// notifications are absorbed. Then the list is unmuted, triggering
  /// a single notification if any element was modified while muted.
  @override
  void unmute() {
    // First unmute all elements while list is still muted.
    // This way, if elements notify, they just mark the list as dirty.
    for (var element in _value) {
      element.unmute();
    }
    // Then unmute list - will notify once if any element was dirty.
    super.unmute();
  }

  /// Override parent's << operator for setting the entire list value.
  @override
  TomList<E> operator <<(List<E> value) {
    // deregister old observers
    _detachFrom(_value);
    // attach new observers
    _attachTo(value);
    // set new value
    _value = List<E>.from(value, growable: true);
    notifyObservers();
    return this;
  }

  /// Appends an element to this list and returns the list for chaining.
  ///
  /// Use this to add single elements:
  /// ```dart
  /// myList.append(element1).append(element2);
  /// ```
  TomList<E> append(E element) {
    _value.add(element);
    element.addObserver(this);
    notifyObservers();
    return this;
  }

  E operator [](int index) {
    return _value[index];
  }

  void operator []=(int index, E value) {
    _value[index].removeObserver(this);
    _value[index] = value;
    value.addObserver(this);
    notifyObservers();
  }

  TomList<E> operator +(TomList<E> other) {
    return TomList.ofList(_value + other._value);
  }

  @override
  bool operator ==(Object other) {
    if (other is TomList) {
      return _value == other._value;
    }
    return false;
  }

  @override
  E get first => _value.first;
  set first(E newFirst) {
    if (!identical(newFirst, _value.first)) {
      _value.first.removeObserver(this);
      _value.first = newFirst;
      _value.first.addObserver(this);
      notifyObservers();
    }
  }

  @override
  E get last => _value.last;
  set last(E newLast) {
    if (!identical(newLast, _value.last)) {
      _value.last.removeObserver(this);
      _value.last = newLast;
      _value.last.addObserver(this);
      notifyObservers();
    }
  }

  @override
  int get length => _value.length;
  set length(int newLength) {
    for (var index = newLength; index < _value.length; index++) {
      _value[index].removeObserver(this);
    }
    _value.length = newLength;
  }

  Iterable<E> get reversed => _value.reversed;

  @override
  int get hashCode => _value.hashCode;

  @override
  bool get isEmpty => _value.isEmpty;
  @override
  bool get isNotEmpty => _value.isNotEmpty;
  @override
  Iterator<E> get iterator => _value.iterator;
  @override
  E get single => _value.single;

  @override
  bool any(bool Function(E e) test) => _value.any(test);
  @override
  List<R> cast<R>() => _value.cast<R>();
  @override
  bool contains(Object? o) => _value.contains(o);
  @override
  E elementAt(int index) => _value.elementAt(index);
  @override
  bool every(bool Function(E e) test) => _value.every(test);
  @override
  Iterable<R> expand<R>(Iterable<R> Function(E e) toElements) =>
      _value.expand<R>(toElements);
  @override
  E firstWhere(bool Function(E e) test, {dynamic Function()? orElse}) =>
      _value.firstWhere(test, orElse: orElse as E Function()?);
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      _value.fold(initialValue, combine);
  @override
  Iterable<E> followedBy(Iterable<dynamic> other) =>
      _value.followedBy(other as Iterable<E>);
  @override
  void forEach(void Function(E element) action) => _value.forEach(action);
  @override
  String join([String separator = ""]) => _value.join(separator);
  @override
  E lastWhere(bool Function(E e) test, {dynamic Function()? orElse}) =>
      _value.lastWhere(test, orElse: orElse as E Function()?);
  @override
  Iterable<T> map<T>(T Function(E e) toElement) => _value.map<T>(toElement);
  @override
  E reduce(dynamic Function(E value, E element) combine) =>
      _value.reduce(combine as E Function(E value, E combine));
  @override
  E singleWhere(bool Function(E e) test, {dynamic Function()? orElse}) =>
      _value.singleWhere(test, orElse: orElse as E Function()?);
  @override
  Iterable<E> skip(int count) => _value.skip(count);
  @override
  Iterable<E> skipWhile(bool Function(E value) test) => _value.skipWhile(test);
  @override
  Iterable<E> take(int count) => _value.take(count);
  @override
  Iterable<E> takeWhile(bool Function(E value) test) => _value.takeWhile(test);
  //List<E> toList() => _value.toList();
  @override
  List<E> toList({bool growable = true}) => _value.toList(growable: growable);
  @override
  Set<E> toSet() => _value.toSet();
  @override
  String toString() => _value.toString();
  @override
  Iterable<E> where(bool Function(E element) test) => _value.where(test);
  @override
  Iterable<T> whereType<T>() => _value.whereType<T>();

  void add(E value) {
    value.addObserver(this);
    _value.add(value);
    notifyObservers();
  }

  void addAll(Iterable<E> iterable) {
    _attachTo(iterable);
    _value.addAll(iterable);
    notifyObservers();
  }

  Map<int, E> asMap() => _value.asMap();
  void clear() {
    _detachFrom(_value);
    _value.clear();
    notifyObservers();
  }

  void fillRange(int start, int end, [E? fillValue]) {
    _detachFrom(getRange(start, end));
    if (fillValue != null) {
      fillValue.addObserver(this);
    }
    _value.fillRange(start, end, fillValue);
    notifyObservers();
  }

  Iterable<E> getRange(int start, int end) => _value.getRange(start, end);
  int indexOf(E element, [int start = 0]) => _value.indexOf(element, start);
  int indexWhere(bool Function(E element) test, [int start = 0]) =>
      _value.indexWhere(test, start);
  void insert(int index, E element) {
    _value.insert(index, element);
    element.addObserver(this);
    notifyObservers();
  }

  void insertAll(int index, Iterable<E> iterable) {
    _value.insertAll(index, iterable);
    _attachTo(iterable);
    notifyObservers();
  }

  int lastIndexOf(E element, [int? start]) =>
      _value.lastIndexOf(element, start);
  int lastIndexWhere(bool Function(E element) test, [int? start]) =>
      _value.lastIndexWhere(test, start);
  bool remove(Object? value) {
    bool result;
    if ((result = _value.remove(value)) &&
        value != null &&
        value is TomObservable) {
      value.removeObserver(this);
    }
    notifyObservers();
    return result;
  }

  E removeAt(int index) {
    var result = _value.removeAt(index);
    result.removeObserver(this);
    notifyObservers();
    return result;
  }

  E removeLast() {
    var result = _value.removeLast();
    result.removeObserver(this);
    notifyObservers();
    return result;
  }

  void removeRange(int start, int end) {
    if (start == end) return;
    _detachFrom(getRange(start, end));
    _value.removeRange(start, end);
    notifyObservers();
  }

  void removeWhere(bool Function(E element) test) {
    if (_detachFrom(where(test))) {
      _value.removeWhere(test);
      notifyObservers();
    }
  }

  void replaceRange(int start, int end, Iterable<E> replacements) {
    removeRange(start, end);
    insertAll(start, replacements);
    notifyObservers();
  }

  void retainWhere(bool Function(E element) test) {
    removeWhere((element) => !test(element));
    notifyObservers();
  }

  void setAll(int index, Iterable<E> iterable) {
    _detachFrom(_value);
    _value.setAll(index, iterable);
    _attachTo(_value);
    notifyObservers();
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _detachFrom(_value);
    _value.setRange(start, end, iterable, skipCount);
    _attachTo(_value);
    notifyObservers();
  }

  void shuffle([Random? random]) {
    _value.shuffle(random);
    notifyObservers();
  }

  void sort([int Function(E a, E b)? compare]) {
    _value.sort(compare);
    notifyObservers();
  }

  List<E> sublist(int start, [int? end]) => _value.sublist(start, end);

  /// Casts a [TomList] from one element type to another.
  static TomList<E> castFrom<S extends TomObject, E extends TomObject>(
    TomList<S> source,
  ) {
    return TomList<E>.ofList(List.castFrom<S, E>(source._value));
  }
}

/// An observable map that automatically observes all contained values.
///
/// [TomMap] wraps a [Map] with [TomObject] values and provides:
/// - Automatic observation of all values (changes in values notify the map)
/// - All standard [Map] operations with observer management
/// - Custom operators for convenient manipulation
///
/// Note: Keys are not observed, only values.
///
/// ## Operators
///
/// - `map[key]` - Get value for key
/// - `map[key] = value` - Set value for key
/// - `map + other` - Merge two TomMaps
///
/// ## Example
///
/// ```dart
/// final users = TomMap<String, Person>();
/// users[\"john\"] = Person();
///
/// users >> (obs) => print(\"Map changed!\");
/// users[\"john\"]!.name | \"John Doe\"; // Triggers observer
/// ```
@tomReflector
class TomMap<K, V extends TomObject> extends TomObject<Map<K, V>>
    implements TomObserver {
  /// Creates an empty observable map.
  TomMap() : super({});

  /// Creates an observable map from an existing [TomMap].
  TomMap.from(TomMap<K, V> existing) : super(Map<K, V>.from(existing._value)) {
    _attachTo(_value.values);
  }

  /// Creates an observable map as a copy of an existing [TomMap].
  TomMap.of(TomMap<K, V> existing) : super(Map<K, V>.of(existing._value)) {
    _attachTo(_value.values);
  }

  /// Creates an observable map from an existing standard [Map].
  TomMap.ofMap(Map<K, V> map) : super(map) {
    _attachTo(map.values);
  }

  void _attachTo(Iterable<V> list) {
    for (var e in list) {
      e.addObserver(this);
    }
  }

  bool _detachFrom(Iterable<V> list) {
    bool didDetach = false;
    for (var e in list) {
      e.removeObserver(this);
      didDetach = true;
    }
    return didDetach;
  }

  /// Throws [TomObservableException] - direct value setting is not allowed.
  ///
  /// Use [add], `[]=` operator, or [addAll] to modify the map.
  @override
  Map<K, V> set(Map<K, V> value) {
    throw TomObservableException(
      "TomClass.tommap_state_error.set_not_allowed",
      "You can't set the value of TomMap, you can only set individuals elements",
    );
  }

  /// Returns a copy of the internal map.
  @override
  Map<K, V> get() {
    return Map.fromEntries(entries);
  }

  /// Called when any observed value changes.
  ///
  /// Propagates the notification to this map's observers.
  @override
  void onNotify(TomObservable observable) {
    notifyObservers();
  }

  /// Mutes this map and all its values.
  ///
  /// While muted, changes to values are tracked but not propagated.
  /// Call [unmute] to resume notifications and trigger a single
  /// consolidated notification if any values were modified.
  @override
  void mute() {
    super.mute();
    for (var value in _value.values) {
      value.mute();
    }
  }

  /// Unmutes this map and all its values.
  ///
  /// Values are unmuted first while the map is still muted, so their
  /// notifications are absorbed. Then the map is unmuted, triggering
  /// a single notification if any value was modified while muted.
  @override
  void unmute() {
    // First unmute all values while map is still muted.
    // This way, if values notify, they just mark the map as dirty.
    for (var value in _value.values) {
      value.unmute();
    }
    // Then unmute map - will notify once if any value was dirty.
    super.unmute();
  }

  /// Gets the value associated with [key], or `null` if not found.
  V? operator [](K key) {
    return _value[key];
  }

  /// Sets the value for [key], observing the new value.
  void operator []=(K key, V value) {
    add(key, value);
  }

  /// Creates a new [TomMap] by merging this map with [other].
  TomMap<K, V> operator +(TomMap<K, V> other) {
    var map = Map.of(_value);
    map.addAll(other._value);
    return TomMap.ofMap(map);
  }

  /// Replaces the entire map with [newMap], updating observers.
  @override
  TomMap<K, V> operator <<(Map<K, V> newMap) {
    _detachFrom(_value.values);
    _attachTo(newMap.values);
    _value = Map<K, V>.of(newMap);
    notifyObservers();
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (other is TomMap) {
      return _value == other._value;
    }
    return false;
  }

  /// The number of key-value pairs in the map.
  int get length => _value.length;

  @override
  int get hashCode => _value.hashCode;

  /// Returns `true` if the map contains no key-value pairs.
  bool get isEmpty => _value.isEmpty;

  /// Returns `true` if the map contains at least one key-value pair.
  bool get isNotEmpty => _value.isNotEmpty;

  /// Returns an iterable of all keys in the map.
  Iterable<K> get keys => _value.keys;

  /// Returns an iterable of all values in the map.
  Iterable<V> get values => _value.values;

  /// Returns an iterable of all key-value pairs in the map.
  Iterable<MapEntry<K, V>> get entries => _value.entries;

  /// Adds a key-value pair to the map.
  ///
  /// If the key already exists, the old value is unobserved and replaced.
  void add(K key, V value) {
    if (_value[key] != null) {
      _value[key]!.removeObserver(this);
    }
    value.addObserver(this);
    _value[key] = value;
    notifyObservers();
  }

  void addAll(Map<K, V> other) {
    _detachFrom(_value.values);
    _value.addAll(other);
    _attachTo(_value.values);
    notifyObservers();
  }

  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    _detachFrom(_value.values);
    _value.addEntries(newEntries);
    _attachTo(_value.values);
    notifyObservers();
  }

  Map<RK, RV> cast<RK, RV>() => _value.cast<RK, RV>();

  void clear() {
    _detachFrom(_value.values);
    _value.clear();
    notifyObservers();
  }

  bool containsKey(K key) => _value.containsKey(key);
  bool containsValue(V value) => _value.containsValue(value);
  void forEach(void Function(K key, V value) action) => _value.forEach(action);
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) =>
      _value.map(convert);
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_value.containsKey(key)) return _value[key]!;
    var newValue = ifAbsent();
    newValue.addObserver(this);
    _value[key] = newValue;
    notifyObservers();
    return newValue;
  }

  V? remove(K? key) {
    if (key == null) return null;
    if (!_value.containsKey(key)) return null;
    var value = _value[key]!;
    value.removeObserver(this);
    return _value.remove(key);
  }

  void removeWhere(bool Function(K key, V value) test) {
    _detachFrom(_value.values);
    _value.removeWhere(test);
    _attachTo(_value.values);
    notifyObservers();
  }

  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    V newValue;
    if (_value.containsKey(key)) {
      var value = _value[key]!;
      value.removeObserver(this);
      newValue = update(value);
      newValue.addObserver(this);
      _value[key] = newValue;
      notifyObservers();
    } else if (ifAbsent != null) {
      newValue = ifAbsent();
      newValue.addObserver(this);
      _value[key] = newValue;
      notifyObservers();
    } else {
      throw TomObservableException(
        "TomClass.tommap_state_error.update_key_not_found_no_ifabsent",
        "Map doesn't contain key $key and no ifAbsent method provided",
      );
    }
    return newValue;
  }

  void updateAll(V Function(K key, V value) update) {
    _detachFrom(_value.values);
    _value.updateAll(update);
    _attachTo(_value.values);
    notifyObservers();
  }

  /// Casts a [TomMap] from one key/value type to another.
  static TomMap<K2, V2> castFrom<
    K,
    V extends TomObject,
    K2,
    V2 extends TomObject
  >(TomMap<K, V> source) {
    return TomMap<K2, V2>.ofMap(Map.castFrom<K, V, K2, V2>(source._value));
  }
}
