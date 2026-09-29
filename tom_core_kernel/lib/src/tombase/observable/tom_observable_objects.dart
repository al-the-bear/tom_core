import 'dart:collection';
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
///
/// This is **one instance shared by the whole program**, so callers test for it
/// by identity (`identical(x, tomNull)`). That sharing is why it is read-only:
/// [TomObject.set] — and therefore `|` and `<<` — throws
/// `observable.null_sentinel.set_not_allowed` rather than writing. A single
/// careless assignment would otherwise be observed by every later reader of the
/// sentinel, in unrelated objects, anywhere in the process.
///
/// It is `final` rather than `const` because [TomObject]'s constructor has a
/// body, so the instance is created at run time; immutability is enforced by
/// the type, not by the language.
final TomObject<String> tomNull = _TomNullObject();

/// The type of [tomNull]: a [TomObject] that refuses to be written.
///
/// Private, so [tomNull] is necessarily the only instance — which is what makes
/// the identity test callers rely on meaningful.
///
/// Only [set] is overridden because every write funnels through it: `|` and
/// `<<` both delegate, so blocking one method blocks all three.
class _TomNullObject extends TomObject<String> {
  _TomNullObject() : super("tomNull");

  /// Throws [TomObservableException] — the shared sentinel is read-only.
  @override
  String set(String value) {
    throw TomObservableException(
      "observable.null_sentinel.set_not_allowed",
      "tomNull is a shared sentinel and cannot be modified. To hold a "
          "changeable value, create your own TomObject instead.",
    );
  }
}

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
/// - `obj | newValue` - Set the value and notify observers, returning the value
/// - `obj << newValue` - Set the value and notify observers, returning `obj`
///   itself so that writes chain
/// - `obj >> callback` - Add an observer callback function
///
/// `|` and `<<` write identically and differ only in what they hand back: use
/// `|` when the value is what you need next, `<<` when you want to keep
/// working on the observable. The composites override `<<` — see [TomList],
/// [TomMap] and [TomClass].
///
/// ## Example
///
/// ```dart
/// final name = TomString("John");
///
/// // Subscribe to changes. Retain the observer — it is held weakly, so
/// // discarding it stops the callback firing at some later point.
/// // The callback is handed the plain TomObservable, so read the value
/// // through the typed variable rather than through the parameter.
/// final observer = name >> (obs) => print("Name changed to: ${~name}");
///
/// // Set new value (triggers observer)
/// name | "Jane";
///
/// // Get value
/// print(~name); // "Jane"
/// print(name()); // "Jane"
///
/// name.removeObserver(observer);
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
  ///
  /// This is the nullable-typed sibling of [get] and nothing more: it delegates
  /// rather than reading the field, so every override of [get] holds here too.
  /// The composites all override [get] precisely because handing out the
  /// backing collection is wrong — [TomList] and [TomMap] return copies, and
  /// [TomClass] refuses outright, having no scalar value to return — and
  /// reading `_value` here would walk past all three.
  T? getOrNull() {
    return get();
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
  ///
  /// Identical to [set] — and therefore to `|` — except in what it returns:
  /// this hands back the observable itself rather than the value, so writes
  /// chain.
  ///
  /// ```dart
  /// final count = TomInt(0);
  /// count << 1 << 2 << 3;   // three writes, three notifications
  /// print(~count);          // 3
  /// ```
  ///
  /// Because it delegates to [set], it inherits the notify-only-on-change
  /// rule: writing the value the cell already holds is silent.
  ///
  /// The chain's static type is `TomObject<T>`, not the subtype it started
  /// from — `TomString("a") << "b"` is a `TomObject<String>`. Chain for the
  /// writes, not to keep hold of a `TomString`.
  ///
  /// The composites override this to mean *wholesale replacement*, which is
  /// not what [set] does on them: see [TomList.operator <<] and
  /// [TomMap.operator <<]. [TomClass.operator <<] throws.
  TomObject<T> operator <<(T value) {
    set(value);
    return this;
  }

  /// Every serialization prefix the wire format defines, mapped to the wrapper
  /// that owns it.
  ///
  /// This is the single source of truth for *which prefix denotes which type*.
  /// Only the construction path consults it. [_createFrom] has to recover a
  /// type from a string and nothing else, because the element it is building
  /// has no cell yet; every path that writes into an **existing** member
  /// dispatches on that member instead — `member is TomOTimezoned` →
  /// [TomOTimezoned.setByString] in [TomClass._setMember], `value is
  /// TomOTimezoned` in [TomClass._serializeMember] — and those are already
  /// polymorphic over the whole zoned family. Adding a zoned flavour is
  /// therefore one entry here plus the flavour's own `setByString`, not an edit
  /// to a dispatch ladder in three files.
  ///
  /// The zoned factories receive the string **with** its prefix, because their
  /// `parseFromString` consumes its own; [TomDateTime] receives it **without**,
  /// because `DateTime.parse` would reject it. Storing factories rather than
  /// constructors is what lets the two conventions coexist in one table.
  static final Map<String, TomObject Function(String)>
  _wrapperFactoriesByPrefix = {
    TomDateTime.serializationPrefix: (s) => TomDateTime(
      DateTime.parse(_stripPrefix(s, TomDateTime.serializationPrefix)),
    ),
    TomZonedDate.serializationPrefix: (s) =>
        TomOZonedDate(TomZonedDate.parseFromString(s)),
    TomZonedTime.serializationPrefix: (s) =>
        TomOZonedTime(TomZonedTime.parseFromString(s)),
    TomZonedDateTime.serializationPrefix: (s) =>
        TomOZonedDateTime(TomZonedDateTime.parseFromString(s)),
  };

  /// Removes [prefix] from the front of [s], or returns [s] unchanged.
  ///
  /// The wire format is `<prefix><payload>`. Both deserialization paths need to
  /// find the payload — [_createFrom] when building a new wrapper and
  /// [TomClass._setMember] when writing into an existing one — and both used to
  /// spell it as a bare `substring(3)`, which silently encodes the assumption
  /// that every marker is three characters long. The length now comes from the
  /// prefix itself.
  static String _stripPrefix(String s, String prefix) =>
      s.startsWith(prefix) ? s.substring(prefix.length) : s;

  /// Creates a [TomObject] wrapper from a dynamic value.
  ///
  /// Automatically determines the appropriate [TomObject] subtype based on
  /// the runtime type of [v]:
  /// - [String] → [TomString] (or a temporal type if it carries a prefix from
  ///   [_wrapperFactoriesByPrefix])
  /// - [DateTime] → [TomDateTime]
  /// - [int] → [TomInt]
  /// - [double] → [TomDouble]
  /// - [bool] → [TomBool]
  /// - [Map] → [TomMap] (recursively wraps values)
  /// - [List] → [TomList] (recursively wraps elements)
  ///
  /// The choice is made from the runtime type of [v] alone; nothing here knows
  /// the destination. An integral number therefore always becomes a [TomInt],
  /// even when the member it is bound for holds doubles — callers that know the
  /// destination type widen the value first with [_widenForDoubleTarget].
  ///
  /// Returns [tomNull] if the type cannot be determined.
  static TomObject _createFrom(dynamic v) {
    if (v is String) {
      for (final entry in _wrapperFactoriesByPrefix.entries) {
        if (v.startsWith(entry.key)) return entry.value(v);
      }
      return TomString(v);
    }
    if (v is DateTime) {
      return TomDateTime(v);
    }
    if (v is int) {
      return TomInt(v);
    }
    if (v is double) {
      return TomDouble(v);
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

  /// Widens an integral number to `double` when the destination type [T] holds
  /// doubles, and returns [v] untouched otherwise.
  ///
  /// JSON has a single number type, so a producer is free to write `20` for a
  /// value the schema calls a double — JavaScript's `JSON.stringify(20.0)` does
  /// exactly that. Widening at a double-holding destination is lossless, so it
  /// happens silently. The reverse is not lossless: narrowing a fractional
  /// number to an `int` destination is left to fail rather than truncated.
  ///
  /// The destination test is `<T>[] is List<TomObject<double?>>` rather than an
  /// equality against [TomDouble]. Covariance makes it true for [TomDouble],
  /// [TomNDouble] and any subclass of either, and false for [TomInt] — and
  /// false for an untyped element type, because `dynamic` is a top type rather
  /// than a subtype of `double?`, so a raw [TomList] keeps its integers as
  /// integers.
  static dynamic _widenForDoubleTarget<T extends TomObject>(dynamic v) =>
      v is int && <T>[] is List<TomObject<double?>> ? v.toDouble() : v;

  /// Builds the wrapper a destination of type [T] should hold for [v].
  ///
  /// [_createFrom] decides from the runtime type of [v] alone, which is the
  /// right rule when nothing is known about the destination and the wrong one
  /// when something is: it only ever builds the *non-nullable* leaves, so a
  /// `TomList<TomNString>` rejected every string it was handed, and a JSON
  /// `null` had no representation among them at all — `_createFrom(null)`
  /// answers [tomNull], which is not an instance of any leaf type.
  ///
  /// Only a nullable destination changes the answer. Every other case is left
  /// to [_createFrom], the untyped destination included, since a member that
  /// commits to no element type asks for nothing: this can therefore widen
  /// what deserialization accepts but never narrow it.
  ///
  /// The destination test is `<TomNXxx>[] is List<T>` and deliberately not its
  /// reverse. [TomObject] is covariant in its value type, so
  /// `<T>[] is List<TomObject<String?>>` is true for [TomString] as well as
  /// [TomNString] and cannot tell the two apart — the same covariance
  /// [_widenForDoubleTarget] relies on, which is exactly why it cannot serve
  /// here. Asking whether the *nullable* wrapper fits the destination can:
  /// `TomNString` is not a `TomString`, because `String?` is not a `String`.
  ///
  /// A value the destination cannot hold falls through to [_createFrom] rather
  /// than throwing, so the mismatch is still reported by the element check in
  /// [TomClass._setListMember], which names the member and the position.
  static TomObject _createForTarget<T extends TomObject>(dynamic v) {
    if (<TomObject<dynamic>>[] is List<T>) return _createFrom(v);

    if (<TomNString>[] is List<T>) {
      if (v == null || v is String) return TomNString(v as String?);
    } else if (<TomNInt>[] is List<T>) {
      if (v == null || v is int) return TomNInt(v as int?);
    } else if (<TomNDouble>[] is List<T>) {
      if (v == null || v is double) return TomNDouble(v as double?);
    } else if (<TomNBool>[] is List<T>) {
      if (v == null || v is bool) return TomNBool(v as bool?);
    } else if (<TomNDateTime>[] is List<T>) {
      if (v == null) return TomNDateTime(null);
      if (v is DateTime) return TomNDateTime(v);
      // The wire form is `@!@<iso8601>`; DateTime.parse would reject the
      // prefix, so it is stripped here exactly as the factory table does.
      if (v is String) {
        return TomNDateTime(
          DateTime.parse(_stripPrefix(v, TomDateTime.serializationPrefix)),
        );
      }
    } else if (<TomNOZonedDate>[] is List<T>) {
      if (v == null) return TomNOZonedDate(null);
      // The zoned parsers consume their own prefix, so the string goes in whole.
      if (v is String) return TomNOZonedDate(TomZonedDate.parseFromString(v));
    } else if (<TomNOZonedTime>[] is List<T>) {
      if (v == null) return TomNOZonedTime(null);
      if (v is String) return TomNOZonedTime(TomZonedTime.parseFromString(v));
    } else if (<TomNOZonedDateTime>[] is List<T>) {
      if (v == null) return TomNOZonedDateTime(null);
      if (v is String) {
        return TomNOZonedDateTime(TomZonedDateTime.parseFromString(v));
      }
    }
    return _createFrom(v);
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
/// The class is abstract, and so is [setByString]: see that method for why a
/// concrete base would be a data-loss hazard. [getSerializationPrefix], by
/// contrast, has a usable default and may simply be inherited.
@tomReflector
abstract class TomOTimezoned<TZ extends TomTimezoned?> extends TomObject<TZ> {
  /// Returns the wire prefix that marks a serialized value of this flavour.
  ///
  /// Defaults to [TomZonedDateTime.serializationPrefix] (`@X@`), which is
  /// correct for the datetime subtypes — they inherit this method rather than
  /// restating it. The date and time subtypes override it with `@D@` / `@T@`.
  ///
  /// Unlike [setByString] this has a defensible default, so it is concrete: a
  /// subtype that inherits the wrong prefix produces a value that is visibly
  /// mislabelled on the wire, not one that vanishes.
  String getSerializationPrefix() {
    return TomZonedDateTime.serializationPrefix;
  }

  /// Sets the value by parsing a serialized string representation.
  ///
  /// This is the **only** entry point for a serialized zoned value:
  /// `TomClass.setOrMergeValues` routes every `String` destined for a
  /// [TomOTimezoned] member through here, because [TomTimezoned] extends
  /// [DateTime] and would otherwise be handed to `DateTime.parse` with its
  /// `@D@`/`@T@`/`@X@` prefix still attached.
  ///
  /// It is abstract rather than an inherited no-op. There is no default that
  /// could be right — the base cannot know which of the three wire formats to
  /// parse — and a subtype that inherited an empty body would drop the field
  /// during deserialization with no throw, no log and no return value to
  /// inspect. Making it abstract turns "forgot to implement it" into a compile
  /// error. A subtype that genuinely has nothing to parse must write the empty
  /// override itself, so that the silence is a stated decision.
  ///
  /// Implementations accept both the prefixed wire form emitted by
  /// [TomTimezoned.toString] and a bare ISO-8601 timestamp.
  void setByString(String s);

  /// A sentinel value representing "no datetime" (Unix epoch in UTC).
  ///
  /// A [TomOZonedDateTime] rather than a bare [TomOTimezoned], which the
  /// abstract base does not permit. The datetime flavour is the right
  /// choice: it is the one whose prefix [getSerializationPrefix] already
  /// returns by default.
  static final TomOTimezoned noDateTime = TomOZonedDateTime(
    TomZonedDateTime.fromDateTime(DateTime.utc(1970)),
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
/// final meetingTime = TomOZonedTime(
///   TomZonedTime.fromDateTime(DateTime.now(), TomTimezone.fromName('Asia/Tokyo')),
/// );
/// ```
@tomReflector
class TomOZonedTime extends TomOTimezoned<TomZonedTime> {
  /// A sentinel value representing "no time" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)` so that the
  /// sentinel denotes the same instant on every machine. A local-time epoch
  /// would shift with the reader's zone, which would make a sentinel
  /// comparison depend on where it runs and would change the meaning of a
  /// persisted "no value" when it crosses zones.
  static final TomZonedTime noZonedTime = TomZonedTime.fromDateTime(
    DateTime.utc(1970),
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
/// final birthDate = TomOZonedDate(
///   TomZonedDate.fromDateTime(DateTime.now(), TomTimezone.fromName('Asia/Tokyo')),
/// );
/// ```
@tomReflector
class TomOZonedDate extends TomOTimezoned<TomZonedDate> {
  /// A sentinel value representing "no date" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)`. A
  /// local-time epoch is not merely offset by a few hours here — because the
  /// value is truncated to a date, a negative UTC offset moves the sentinel to
  /// the *previous day*.
  static final TomZonedDate noZonedDate = TomZonedDate.fromDateTime(
    DateTime.utc(1970),
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

  TomOZonedDate(super.initialValue) : super._();
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
  /// A sentinel value representing "no datetime" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)` so that the
  /// sentinel denotes the same instant on every machine.
  static final TomZonedDateTime noZonedDateTime = TomZonedDateTime.fromDateTime(
    DateTime.utc(1970),
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

  TomOZonedDateTime(super.initialValue) : super._();
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
///
/// Abstract for the same reason as [TomOTimezoned]: it adds no parsing of its
/// own, so leaving it concrete would give it an inherited [setByString] with
/// no implementation behind it.
@tomReflector
abstract class TomNOTimezoned<TZ extends TomTimezoned?>
    extends TomOTimezoned<TZ> {
  /// A sentinel value representing "no datetime" (Unix epoch in UTC).
  ///
  /// A [TomNOZonedDateTime] rather than a bare [TomNOTimezoned] — see
  /// [TomOTimezoned.noDateTime].
  static final TomNOTimezoned noDateTime = TomNOZonedDateTime(
    TomZonedDateTime.fromDateTime(DateTime.utc(1970)),
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
  /// A sentinel value representing "no time" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)` so that the
  /// sentinel denotes the same instant on every machine. A local-time epoch
  /// would shift with the reader's zone, which would make a sentinel
  /// comparison depend on where it runs and would change the meaning of a
  /// persisted "no value" when it crosses zones.
  static final TomZonedTime noZonedTime = TomZonedTime.fromDateTime(
    DateTime.utc(1970),
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
  /// A sentinel value representing "no date" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)`. A
  /// local-time epoch is not merely offset by a few hours here — because the
  /// value is truncated to a date, a negative UTC offset moves the sentinel to
  /// the *previous day*.
  static final TomZonedDate noZonedDate = TomZonedDate.fromDateTime(
    DateTime.utc(1970),
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
  /// A sentinel value representing "no datetime" (the Unix epoch, in UTC).
  ///
  /// Built from `DateTime.utc(1970)` rather than `DateTime(1970)` so that the
  /// sentinel denotes the same instant on every machine.
  static final TomZonedDateTime noZonedDateTime = TomZonedDateTime.fromDateTime(
    DateTime.utc(1970),
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
/// Both dates are nullable [TomNOZonedDate] values, allowing open-ended
/// ranges, and a fresh range holds `null` at both ends.
///
/// `null` rather than the `noZonedDate` epoch sentinel, because the two
/// families answer "no value" differently and these members belong to the
/// nullable one: [TomOZonedDate.setByString] turns an empty `@D@` into the
/// sentinel, [TomNOZonedDate.setByString] turns it into `null`. Initialising a
/// nullable member with the other family's sentinel gave a range two distinct
/// empty states — a fresh one where [TomObject.isNull] answered `false`, and
/// one deserialized from an empty marker where it answered `true` — so a
/// consumer branching on `isNull` got different answers for two ranges that
/// were both unset, and a fresh range serialized two timestamps nobody had
/// entered.
///
/// Example:
/// ```dart
/// final vacation = TomDateRange();
/// final today = DateTime.now();
/// vacation.startDate | TomZonedDate.fromDateTime(today);
/// // Add the duration to the `DateTime`, before wrapping: arithmetic
/// // inherited from `DateTime` returns a plain `DateTime`, not a zoned one.
/// vacation.endDate | TomZonedDate.fromDateTime(today.add(Duration(days: 7)));
/// ```
@tomReflector
class TomDateRange extends TomClass {
  /// The start date of the range, or `null` when the range is open at the
  /// start.
  TomNOZonedDate startDate = TomNOZonedDate(null);

  /// The end date of the range, or `null` when the range is open at the end.
  TomNOZonedDate endDate = TomNOZonedDate(null);
}

/// An observable time range with start and end times.
///
/// Both times are nullable [TomNOZonedTime] values, allowing open-ended
/// ranges. A fresh range holds `null` at both ends — see [TomDateRange] for
/// why that is `null` and not the epoch sentinel.
@tomReflector
class TomTimeRange extends TomClass {
  /// The start time of the range, or `null` when the range is open at the
  /// start.
  TomNOZonedTime startTime = TomNOZonedTime(null);

  /// The end time of the range, or `null` when the range is open at the end.
  TomNOZonedTime endTime = TomNOZonedTime(null);
}

/// An observable datetime range with start and end datetimes.
///
/// Both datetimes are nullable [TomNOZonedDateTime] values, allowing
/// open-ended ranges. A fresh range holds `null` at both ends — see
/// [TomDateRange] for why that is `null` and not the epoch sentinel.
@tomReflector
class TomDateTimeRange extends TomClass {
  /// The start datetime of the range, or `null` when the range is open at the
  /// start.
  TomNOZonedDateTime startDateTime = TomNOZonedDateTime(null);

  /// The end datetime of the range, or `null` when the range is open at the
  /// end.
  TomNOZonedDateTime endDateTime = TomNOZonedDateTime(null);
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
/// ## Operators
///
/// A class is addressed through its members, so the whole-value operators do
/// not apply to it: [get], [set] and `<<` all throw. Write members
/// individually (`person.name | "John"`) or many at once with [setValues].
/// `>>` works as it does on any observable, and fires for a change to any
/// member.
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
      "observable.class_state.set_not_allowed",
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
      "observable.class_state.get_not_allowed",
      "You can't get the value of TomClass, you can only get individuals fields",
    );
  }

  /// Throws [TomObservableException] — a class has no single value to replace.
  ///
  /// This is the one place where `<<` is *not* available, and the asymmetry
  /// with [TomList.operator <<] and [TomMap.operator <<] is deliberate: their
  /// contents are replaceable, whereas a class's set of members is fixed by its
  /// declaration. Replacing it wholesale is not a write, it is a different
  /// object.
  ///
  /// To write many members at once, use [setValues] (or [setOrMergeValues]),
  /// which addresses the members by name and leaves the shape alone.
  @override
  TomClass operator <<(Map<String, dynamic> value) {
    throw TomObservableException(
      "observable.class_state.set_not_allowed",
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

  /// Registers every reflected [TomObservable] getter of [cm] as a member, then
  /// recurses into the superclass.
  ///
  /// ## Member names are always public
  ///
  /// The key is `member.simpleName`, taken from the reflected getter, and
  /// reflection excludes private fields and private accessors — so a member
  /// key can never begin with an underscore. A private field published through
  /// a public getter registers under the **getter's** name:
  ///
  /// ```dart
  /// final TomString _label = TomString("");
  /// TomString get label => _label;   // registers as "label"
  /// ```
  ///
  /// This is why [setOrMergeValues] looks a key up once and does not also try
  /// an underscore-prefixed variant. It used to, and that fallback could never
  /// fire: the name it searched for was one reflection is incapable of
  /// producing.
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
        "observable.class_initialization.could_not_register_superclass_members",
        "Failure during TomClass superclass member registration for observable notifications",
        rootException: e,
        stack: s,
      );
    }
  }

  /// A read-only view of [_value], handed out by [getMembers].
  ///
  /// A view rather than a copy, so it stays correct as registration proceeds —
  /// [_registerWithMembers] walks the superclass chain after the subclass, so a
  /// caller holding a snapshot taken early would be missing members. Built once
  /// because [getMembers] is called per row by the datasource layer.
  late final Map<String, TomObject> _memberView = UnmodifiableMapView(_value);

  /// Returns a **read-only** view of all registered [TomObject] members.
  ///
  /// Keys are the field names, values are the [TomObject] instances. The view
  /// is live: members registered later appear in it.
  ///
  /// Mutating the returned map throws [UnsupportedError]. Registration is not a
  /// caller's decision — it is derived from the declared fields, and a removal
  /// from the map would deregister the member without detaching the observer
  /// wiring [_registerWithMembers] installed, leaving a half-attached object
  /// that nothing outside the class can repair. The members themselves are the
  /// live cells, so reading one and assigning through it works as usual.
  Map<String, TomObject> getMembers() {
    return _memberView;
  }

  /// Called when any observed member changes.
  ///
  /// Propagates the notification to this [TomClass]'s own observers.
  @override
  void onNotify(TomObservable observable) {
    notifyObservers();
  }

  /// Muting a [TomClass] mutes its members, so that a batch spanning several
  /// fields surfaces as one notification from the class rather than one per
  /// field.
  @override
  Iterable<TomObservable> get muteCascadeTargets => _value.values;

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
  ///
  /// ## Failure
  ///
  /// The input is usually decoded JSON, so a value of the wrong shape is an
  /// ordinary occurrence rather than a programming error, and the method is
  /// written to survive one:
  ///
  /// - The work runs inside a [batch], which releases in a `finally`, so a
  ///   rejected value cannot leave the object — or its members, which the
  ///   batch cascades to — permanently silent. Whatever was applied before the
  ///   failure is announced at that point: the object *has* changed, and
  ///   hiding it would be worse than reporting a partial update.
  /// - Whatever the underlying failure was, it surfaces as a
  ///   [TomObservableException] naming the offending key and the runtime type
  ///   actually supplied. Unwrapped, a mistyped member surfaces as a bare
  ///   `TypeError` from deep inside a cast, which identifies neither.
  void setOrMergeValues(Map<String, dynamic> values, bool merge) {
    batch(() {
      for (var key in values.keys) {
        // Keys are matched against the member's registered name, which is
        // always the *public* one — see [_registerWithMembers]. An unknown key
        // is skipped rather than rejected: the input is usually decoded JSON,
        // and a payload carrying fields this class does not declare is an
        // ordinary occurrence, not an error.
        final TomObject? member = _value[key];
        if (member == null) continue;
        final value = values[key];
        try {
          _setMember(member, value, key, merge);
        } on TomObservableException {
          // Already named its own key — a nested TomClass, or one of the
          // collection helpers below. Wrapping again would bury that key
          // under this one.
          rethrow;
        } catch (exception, stacktrace) {
          throw TomObservableException(
            "observable.class_set_values.member_assignment_failed",
            "Failed to set TomClass member '$key' from a "
                "${value.runtimeType}: $exception",
            parameters: {"key": key, "valueType": "${value.runtimeType}"},
            rootException: exception,
            stack: stacktrace,
          );
        }
      }
    });
  }

  /// Applies one deserialized [value] to one [member], dispatching on the
  /// member's observable type.
  void _setMember(TomObject member, dynamic value, String key, bool merge) {
    if (member is TomClass) {
      member.setOrMergeValues(value, merge);
      return;
    }
    if (member is TomList) {
      _setListMember(member, value, key, !merge);
      return;
    }
    if (member is TomMap) {
      _setMapMember(member, value, key, !merge);
      return;
    }
    if (member is TomOTimezoned && value is String) {
      // Must be tested *before* the plain-DateTime branch below: TomTimezoned
      // extends DateTime, so every zoned member also satisfies
      // `TomObject<DateTime?>` and would otherwise be handed to DateTime.parse
      // with its own `@D@`/`@T@`/`@X@` prefix still attached.
      member.setByString(value);
      return;
    }
    if ((member is TomDateTime ||
            member is TomObject<DateTime> ||
            member is TomObject<DateTime?>) &&
        value is String) {
      // The wire format is `<prefix><iso8601>` (see getValues()). Accept both
      // the prefixed and bare forms. Only this member's own prefix is stripped:
      // a foreign prefix is left in place so that DateTime.parse rejects it,
      // rather than being trimmed into something that might parse by accident.
      member.set(
        DateTime.parse(
          TomObject._stripPrefix(value, TomDateTime.serializationPrefix),
        ),
      );
      return;
    }
    if (member is TomObject<double?> && value is int) {
      // A double-holding member reached by an integral number: JSON has one
      // number type, so widen rather than reject. `TomObject<double?>` covers
      // both TomDouble and TomNDouble by covariance — see
      // TomObject._widenForDoubleTarget for why the check is shaped this way.
      member.set(value.toDouble());
      return;
    }
    if (value is List) {
      final typed = _primitiveListFor(member, value);
      if (typed != null) {
        member.set(typed);
        return;
      }
    }
    member.set(value);
  }

  /// [value] re-typed for a scalar member holding a whole list of primitives,
  /// or `null` when [member] is not one.
  ///
  /// `getValues()` serializes a `TomList<TomString>` as a plain
  /// `List<dynamic>`, and a member typed `TomObject<List<String>>` — a
  /// multi-select form field is exactly that — rejects the dynamic list in
  /// `set`, so a state's own serialization could not be bound back. The same
  /// asymmetry holds for every primitive the framework serializes, so each is
  /// re-typed here, next to the int-into-double widening that answers the same
  /// round-trip problem for a single number; a `List<double>` member widens its
  /// integral elements too. Re-typing is not coercion: an element of the wrong
  /// type throws, and the assignment fails as a scalar's would.
  ///
  /// Each test is written against the nullable list type, so a member holding
  /// `List<String>` and one holding `List<String>?` both match by covariance.
  static List<Object?>? _primitiveListFor(TomObject member, List value) {
    if (member is TomObject<List<String>?>) return List<String>.from(value);
    if (member is TomObject<List<double>?>) {
      return <double>[for (final element in value) (element as num).toDouble()];
    }
    if (member is TomObject<List<int>?>) return List<int>.from(value);
    if (member is TomObject<List<bool>?>) return List<bool>.from(value);
    return null;
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
      // An untyped value type accepts anything and is not a TomClass, so every
      // entry takes the value path below and no mirror is needed. Asking for
      // one would fail rather than answer: `TomObject<dynamic>` is generic, and
      // the resolver refuses a generic value type because for every committed
      // member shape that means a nested collection.
      final memberMirror = member._hasUntypedValues
          ? null
          : tomReflectionInfo.mapValueElementType(member);
      for (var key in value.keys) {
        var element = value[key];
        // `isSubtypeOf`, not `isAssignableTo`: the latter is deliberately
        // bidirectional (`a.isSubtypeOf(b) || b.isSubtypeOf(a)`), so a
        // *supertype* of TomClass passes it too — `TomObject` does — and the
        // instance this branch then constructs is not a TomClass at all. Asked
        // the narrow way, the cast below cannot fail.
        if (memberMirror != null &&
            memberMirror.isSubtypeOf(TomClass._classMirror)) {
          final obj = memberMirror.newInstance("", []) as TomClass;
          if (element is Map<String, dynamic>) {
            obj.setValues(element);
          } else {
            throw TomObservableException(
              "observable.class_set_map_member.invalid_element_type",
              "TomClass elements of type ${memberMirror.simpleName} must be deserialized from Map objects but found ${element.runtimeType}",
            );
          }
          member[key] = obj;
        } else {
          member[key] = member._valueFrom(member._widenValue(element));
        }
      }
    } else {
      throw TomObservableException(
        "observable.class_set_map_member.not_a_map",
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
    if (value is! List) {
      throw TomObservableException(
        "observable.class_set_list_member.not_a_list",
        "TomList member $key must get deserialized from a list, but ${value.runtimeType} ",
      );
    }
    // Build all new element instances before touching the list so that
    // resetWith() (used when clear=true) can fire onBeforeClear while the
    // old elements are still intact, then install all new elements, then
    // fire onAfterReset with a fully populated list.
    // See `_setMapMember`: an untyped element type is not a TomClass and
    // cannot be resolved, so the mirror is skipped and every element takes the
    // value path.
    final memberMirror = member._hasUntypedElements
        ? null
        : tomReflectionInfo.singleElementType(member);
    final newElements = <TomObject<dynamic>>[];
    for (var element in value) {
      // See `_setMapMember` for why this asks `isSubtypeOf` rather than
      // `isAssignableTo`.
      if (memberMirror != null &&
          memberMirror.isSubtypeOf(TomClass._classMirror)) {
        final obj = memberMirror.newInstance("", []) as TomClass;
        if (element is Map<String, dynamic>) {
          obj.setValues(element);
        } else {
          throw TomObservableException(
            "observable.class_set_list_member.not_a_map",
            "TomClass elements of type ${memberMirror.simpleName} must be deserialized from Map objects but found ${element.runtimeType}",
          );
        }
        newElements.add(obj);
      } else {
        newElements.add(member._elementFrom(member._widenElement(element)));
      }
    }
    // Check every element against the member's declared element type before
    // installing any of them. Left to the install step, the mismatch surfaces
    // as a bare `TypeError` from the covariant `add`/`as E` check — which names
    // neither the member nor the position — and, worse, surfaces *after*
    // `_resetWithDynamic` has already cleared the list, so a rejected payload
    // would destroy the data it failed to replace.
    for (var i = 0; i < newElements.length; i++) {
      final candidate = newElements[i];
      if (!member._acceptsElement(candidate)) {
        throw TomObservableException(
          "observable.class_set_list_member.invalid_element_type",
          "TomList member '$key' element $i cannot be deserialized from a "
              "${value[i].runtimeType}: that yields a "
              "${candidate.runtimeType}, but the list holds "
              "${memberMirror?.simpleName ?? member._elementTypeName}",
          parameters: {
            "key": key,
            "index": i,
            "valueType": "${value[i].runtimeType}",
            "elementType": "${candidate.runtimeType}",
          },
        );
      }
    }
    if (clear) {
      // Atomically replace all elements — fires onBeforeClear / onAfterReset
      // lifecycle hooks so registered TomListLifecycleListeners (e.g.
      // TomListForm) can tear down and recreate sub-state in one pass.
      // Use the loosely-typed variant: `newElements` is a
      // `List<TomObject<dynamic>>` whose reified type is not `List<E>`, so the
      // covariant `resetWith(Iterable<E>)` parameter check would reject it even
      // though every element is really an `E`.
      member._resetWithDynamic(newElements);
    } else {
      for (final e in newElements) {
        member.add(e);
      }
    }
  }

  /// Returns all member values as a map.
  ///
  /// The returned map can be used for JSON serialization. Nested [TomClass]
  /// instances are recursively converted. DateTime and timezone values are
  /// serialized with their appropriate prefixes.
  Map<String, dynamic> getValues() {
    Map<String, Object?> result = {};
    for (var key in _value.keys) {
      var value = _value[key]!;
      try {
        result[key] = _serializeMember(value);
      } on TomObservableException {
        // A nested TomClass member already wrapped and logged the failure
        // (and named its own offending key); propagate it unchanged rather
        // than double-wrapping.
        rethrow;
      } catch (exception, stacktrace) {
        // Never swallow a member serialization failure into silent partial
        // data: name the offending member, route diagnostics through tomLog
        // (TomException autoLog), and rethrow so callers see the failure.
        throw TomObservableException(
          "observable.class_get_values.member_serialization_failed",
          "Failed to serialize TomClass member '$key': $exception",
          parameters: {"key": key},
          rootException: exception,
          stack: stacktrace,
          autoLog: true,
        );
      }
    }
    return result;
  }

  /// Serializes a single observable member to a JSON-safe value.
  ///
  /// Applies the same per-type handling to a member as [getValues] applies to a
  /// `TomClass`'s own fields — and, crucially, is reused for the **elements** of
  /// a [TomList] and the **values** of a [TomMap]. Both containers' `get()`
  /// returns the backing collection with its `TomObject`s still wrapped, so a
  /// `TomList<TomString>` or a `TomMap<String, TomInt>` — or either holding
  /// nested `TomClass`es — would otherwise leak raw `TomObject` instances into
  /// `jsonEncode`, which refuses them. Nested containers recurse the same way.
  ///
  /// A map's keys pass through unchanged. The value side is the one that holds
  /// `TomObject`s; a key is whatever `K` is, and [setValues] restores it from
  /// the decoded map's own keys, so rewriting keys here would break the round
  /// trip rather than serve it.
  static Object? _serializeMember(TomObject value) {
    // Check for TomClass before calling .get(), since TomClass.get() throws.
    if (value is TomClass) return value.getValues();
    if (value is TomList) {
      return [for (final element in value) _serializeMember(element)];
    }
    if (value is TomMap) {
      return {
        for (final entry in value.entries)
          entry.key: _serializeMember(entry.value),
      };
    }
    final valueValue = value.get();
    // Every DateTime-holding observable reaches one of the two branches below:
    // the plain pair here, and all six zoned types through TomOTimezoned, which
    // TomNOTimezoned extends. TomDateTimeRange is a TomClass and was taken
    // above. A new DateTime-derived type needs a branch here and a matching
    // one in setOrMergeValues, or it serializes as a bare `DateTime`.
    if (value is TomDateTime || value is TomNDateTime) {
      // Emit `<prefix><iso8601>` for round-trip via setValues(), which strips
      // the prefix and DateTime.parse()s the rest (see setOrMergeValues above).
      // Nullable variants emit `null` when the underlying value is unset.
      return valueValue == null
          ? null
          : "${TomDateTime.serializationPrefix}"
                "${(valueValue as DateTime).toIso8601String()}";
    }
    if (value is TomOTimezoned) {
      return valueValue != null
          ? valueValue.toString()
          : value.getSerializationPrefix();
    }
    return valueValue;
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

// ---------------------------------------------------------------------------
// TomListLifecycleListener
// ---------------------------------------------------------------------------

/// Listener for structural reset events on a [TomList].
///
/// Register via [TomList.addLifecycleListener]. Implementors are notified
/// around the [TomList.resetWith] batch-replacement operation so they can
/// tear down state tied to the old elements before the list is cleared and
/// re-create state for the new elements after they are installed.
///
/// This is the mechanism used by `TomListForm` in `tom_flutter_ui` to
/// keep its sub-form instances in sync when `TomClass.setValues()` replaces
/// the contents of a list member (e.g. when an outer form discards its
/// changes and restores the bind-time snapshot).
abstract class TomListLifecycleListener {
  /// Called immediately **before** all elements are removed from [list].
  /// The list is still intact when this fires — implementors may read
  /// current elements for cleanup.
  void onBeforeClear(TomList list) {}

  /// Called immediately **after** new elements have been installed in
  /// [list]. The list is fully populated when this fires — implementors
  /// may read the new contents to recreate state.
  void onAfterReset(TomList list) {}
}

/// An observable list that automatically observes all contained elements.
///
/// [TomList] wraps a [List] of [TomObject] elements and provides:
/// - Automatic observation of all elements (changes in elements notify the list)
/// - All standard [List] operations with observer management
/// - Custom operators for convenient element manipulation
///
/// It implements [Iterable], **not** [List]: the standard operations are
/// provided, but a `TomList<E>` is not assignable to a `List<E>`. Use [toList]
/// (which returns a copy) at a boundary that insists on the `dart:core` type,
/// or type the parameter as `Iterable<E>`.
///
/// ## Methods
///
/// - `list.append(element)` - Add an element (returns the list for chaining)
/// - `list[index]` - Get element at index
/// - `list[index] = value` - Set element at index
/// - `list + other` - Concatenate two TomLists
/// - `list << [a, b]` - Replace **all** elements in one notification, returning
///   the list (see [TomList.operator <<]). Note that `<<` swaps the contents
///   wholesale; to add a single element, use `append`
///
/// ## Notification contract
///
/// **A mutator notifies exactly once when it changed the list's contents, and
/// not at all when it left them as they were.** `clear()` on an empty list,
/// `addAll([])`, `sort()` on an already-sorted list and `list[0] = list[0]` are
/// all silent. "Contents" means the sequence of element *references*, compared
/// by identity — swapping in an equal-but-distinct element is a real change,
/// because observers hold references. A change *inside* an element is not the
/// mutator's business: it reaches observers through [onNotify].
///
/// The one deliberate exception is [resetWith], which notifies even when the
/// new contents happen to equal the old ones — its lifecycle listeners have
/// already torn down and rebuilt whatever they hold per element.
///
/// ## Example
///
/// ```dart
/// final items = TomList<TomString>();
/// items.append(TomString("first"));
/// items.append(TomString("second"));
///
/// // Retain the observer — it is held weakly.
/// final observer = items >> (obs) => print("List changed!");
/// items[0] | "updated"; // Triggers observer
///
/// items.removeObserver(observer);
/// ```
@tomReflector
class TomList<E extends TomObject> extends TomObject<List<E>>
    implements TomObserver, Iterable<E> {
  /// Registered lifecycle listeners.
  final List<TomListLifecycleListener> _lifecycleListeners = [];

  /// Register a [TomListLifecycleListener] to be called around structural
  /// batch-replacement operations (see [resetWith]).
  void addLifecycleListener(TomListLifecycleListener listener) {
    _lifecycleListeners.add(listener);
  }

  /// Unregister a previously added [TomListLifecycleListener].
  void removeLifecycleListener(TomListLifecycleListener listener) {
    _lifecycleListeners.remove(listener);
  }

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

  /// The current element sequence, for a later [_notifyIfChangedSince].
  ///
  /// Taken by the mutators whose outcome is not knowable in advance — a `sort`
  /// of an already-sorted list, a `setRange` that writes back what was there.
  /// Mutators that always change the list (`add`, `insert`, `removeAt`) notify
  /// directly instead of paying for the copy.
  List<E> _snapshot() => List<E>.of(_value);

  /// Notifies observers only if the element sequence differs from [before].
  ///
  /// Compared by identity, not equality: observers hold element references, so
  /// swapping in an equal-but-distinct element is a real change. A change
  /// *inside* an element is not this method's business — it reaches observers
  /// through [onNotify].
  void _notifyIfChangedSince(List<E> before) {
    if (before.length != _value.length) {
      notifyObservers();
      return;
    }
    for (var i = 0; i < before.length; i++) {
      if (!identical(before[i], _value[i])) {
        notifyObservers();
        return;
      }
    }
  }

  /// Always throws [TomObservableException]: a list is never assigned wholesale
  /// through [set].
  ///
  /// Replacing the backing list here would leave the outgoing elements still
  /// registered as observed and the incoming ones unobserved — the list would
  /// go quiet for every element it now holds. The operations that *do* replace
  /// the contents perform that exchange properly: [operator <<] for an ordinary
  /// swap, [resetWith] when the lifecycle callbacks are wanted too. For single
  /// elements use [add], [addAll], or index assignment.
  @override
  List<E> set(List<E> value) {
    throw TomObservableException(
      "observable.list_state.set_not_allowed",
      "You can't set the value of TomList, you can only set individuals elements",
    );
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

  /// Muting a list mutes its elements, so that a batch touching several
  /// elements surfaces as one notification from the list.
  @override
  Iterable<TomObservable> get muteCascadeTargets => _value;

  /// Replaces every element with [value] and returns this list.
  ///
  /// This is the operator form of a wholesale swap, and on a list it is not
  /// what [set] does — [set] throws, because replacing the backing list behind
  /// the element observers would silently strand them. `<<` performs the swap
  /// *properly*: it detaches the outgoing elements, attaches the incoming ones,
  /// and emits **one** notification for the whole exchange rather than one per
  /// element.
  ///
  /// ```dart
  /// final rows = TomList<TomString>();
  /// rows << [TomString('x'), TomString('y')];   // one notification
  /// ```
  ///
  /// Silent if the new sequence is element-for-element **identical** to the
  /// old one. The comparison is by identity, not equality, because observers
  /// hold element references: swapping in an equal-but-distinct element is a
  /// real change. See [resetWith] for the same swap with lifecycle callbacks,
  /// which for that reason notifies unconditionally.
  @override
  TomList<E> operator <<(List<E> value) {
    final before = _snapshot();
    // deregister old observers
    _detachFrom(_value);
    // attach new observers
    _attachTo(value);
    // set new value
    _value = List<E>.from(value, growable: true);
    _notifyIfChangedSince(before);
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
    if (identical(_value[index], value)) return;
    _value[index].removeObserver(this);
    _value[index] = value;
    value.addObserver(this);
    notifyObservers();
  }

  TomList<E> operator +(TomList<E> other) {
    return TomList.ofList(_value + other._value);
  }

  /// Identity, **not** contents: a list equals only itself.
  ///
  /// Two lists holding equal elements are unequal, and that is deliberate. A
  /// `TomList` is a mutable cell, so a content-based equality would need a
  /// content-based [hashCode], and an object whose hash changes while it sits
  /// in a `Set` or serves as a `Map` key can no longer be found there. Dart's
  /// own `List` and `Map` decline content equality for exactly this reason,
  /// and so does every other observable in this library — [TomObject],
  /// [TomClass] and the scalars all inherit identity equality from `Object`.
  /// This override states the same rule explicitly, because a type that
  /// implements `Iterable` invites the opposite assumption.
  ///
  /// Identity is also the honest answer for what the type *is*: observers
  /// register per instance, so two lists with equal elements are different
  /// cells with different observers and different parents.
  ///
  /// To compare contents, unwrap the elements. Those are observables too and
  /// compare by identity in turn, so comparing the raw lists — `~a == ~b`, or
  /// any list-equality helper over them — is **not** enough:
  ///
  /// ```dart
  /// bool sameContents(TomList<TomInt> a, TomList<TomInt> b) =>
  ///     a.length == b.length &&
  ///     Iterable<int>.generate(a.length).every((i) => ~a[i] == ~b[i]);
  /// ```
  ///
  /// For a list of nested [TomClass] elements compare `getValues()` per
  /// element instead.
  @override
  bool operator ==(Object other) => identical(this, other);

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

  /// Truncates the list to [newLength], deregistering the dropped elements.
  ///
  /// Growing is rejected: a `TomList` holds non-nullable elements, so there is
  /// nothing to pad with. Left to the underlying list the attempt fails anyway,
  /// but as a bare `TypeError` about `Null` that names neither the list nor the
  /// operation. Use [add], [addAll] or [insert] to make a list longer.
  set length(int newLength) {
    if (newLength == _value.length) return;
    if (newLength > _value.length) {
      throw TomObservableException(
        "observable.list_state.length_cannot_grow",
        "A TomList cannot be grown by assigning its length: going from "
            "${_value.length} to $newLength would need elements that do not "
            "exist. Use add, addAll or insert instead.",
        parameters: {"length": _value.length, "newLength": newLength},
      );
    }
    for (var index = newLength; index < _value.length; index++) {
      _value[index].removeObserver(this);
    }
    _value.length = newLength;
    notifyObservers();
  }

  Iterable<E> get reversed => _value.reversed;

  /// The identity hash, and therefore **stable across every mutation**.
  ///
  /// Agrees with [operator ==], which compares by identity — see there for why
  /// a hash that tracked the contents would be actively harmful on a cell whose
  /// contents change. Hashing the backing list instead would break twice over:
  /// [operator <<] installs a *new* backing list, so the hash of a list already
  /// filed in a `Set` would move underneath it.
  @override
  int get hashCode => identityHashCode(this);

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

  /// A **read-only** re-typed view of this list.
  ///
  /// `List.cast` alone returns a writable view: `list.cast<TomObject>().add(x)`
  /// reaches the backing list, and the observers never hear about it. Wrapping
  /// keeps `cast`'s liveness — later elements show up — while refusing the
  /// writes that only the mutators may perform.
  @override
  List<R> cast<R>() => UnmodifiableListView(_value.cast<R>());
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
  E firstWhere(bool Function(E e) test, {E Function()? orElse}) =>
      _value.firstWhere(test, orElse: orElse);
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      _value.fold(initialValue, combine);
  @override
  Iterable<E> followedBy(Iterable<E> other) => _value.followedBy(other);
  @override
  void forEach(void Function(E element) action) => _value.forEach(action);
  @override
  String join([String separator = ""]) => _value.join(separator);
  @override
  E lastWhere(bool Function(E e) test, {E Function()? orElse}) =>
      _value.lastWhere(test, orElse: orElse);
  @override
  Iterable<T> map<T>(T Function(E e) toElement) => _value.map<T>(toElement);
  @override
  E reduce(E Function(E value, E element) combine) => _value.reduce(combine);
  @override
  E singleWhere(bool Function(E e) test, {E Function()? orElse}) =>
      _value.singleWhere(test, orElse: orElse);
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

  /// Replace the entire list contents atomically.
  ///
  /// Fires [TomListLifecycleListener.onBeforeClear] on all registered
  /// listeners before removing the current elements, installs [elements] as
  /// the new contents, then fires [TomListLifecycleListener.onAfterReset]
  /// so listeners can recreate state for the new contents.  A single
  /// [notifyObservers] call is made after all elements are installed.
  ///
  /// [TomClass._setListMember] uses this method so that observers such as
  /// `TomListForm` can teardown / recreate their sub-form instances when
  /// a parent form writes its bind-time snapshot back via `setValues()`.
  void resetWith(Iterable<E> elements) => _resetWithDynamic(elements);

  /// Whether [candidate] may be stored in this list.
  ///
  /// [TomClass._setListMember] builds elements reflectively and holds them as
  /// `TomObject<dynamic>`, so it cannot express the `is E` test itself — `E` is
  /// only in scope here. Asking the list lets a mistyped element be reported
  /// before it is installed rather than as a covariant-check `TypeError` after
  /// the list has already been cleared.
  bool _acceptsElement(TomObject<dynamic> candidate) => candidate is E;

  /// Widens a deserialized [raw] number to `double` when this list holds
  /// doubles, leaving every other value untouched.
  ///
  /// Like [_acceptsElement], this exists because `E` is only in scope here:
  /// [TomClass._setListMember] knows the raw JSON value but not the element
  /// type. See [TomObject._widenForDoubleTarget] for the rule itself.
  dynamic _widenElement(dynamic raw) => TomObject._widenForDoubleTarget<E>(raw);

  /// Builds the element this list should hold for [raw].
  ///
  /// Like [_acceptsElement] and [_widenElement] this exists because `E` is
  /// only in scope here: [TomClass._setListMember] holds the raw JSON value
  /// but not the element type it has to become.
  TomObject<dynamic> _elementFrom(dynamic raw) =>
      TomObject._createForTarget<E>(raw);

  /// Whether this list's element type is the untyped base [TomObject].
  ///
  /// True for `TomList<TomObject>` and false for `TomList<TomDouble>` or any
  /// other committed element type. Like [_acceptsElement] it lives here
  /// because `E` is only in scope here, and it is the question
  /// [TomClass._setListMember] has to answer *before* it can ask reflection
  /// anything: an untyped element type is generic, and the resolver rejects a
  /// generic element type because for every other member shape that means a
  /// nested collection.
  bool get _hasUntypedElements => <TomObject<dynamic>>[] is List<E>;

  /// The declared element type, named as Dart names it, for error messages.
  String get _elementTypeName => '$E';

  /// Loosely-typed variant of [resetWith] used by deserialization.
  ///
  /// [TomClass._setListMember] builds new elements reflectively into a
  /// `List<TomObject<dynamic>>`; every element is really an `E`, but the list's
  /// *reified* type is not `List<E>`. Passing it to [resetWith] fails the
  /// covariant `Iterable<E>` parameter check at method entry, before the body
  /// runs. This variant's parameter type does not mention `E`, so no
  /// whole-container covariant check happens — each element is instead checked
  /// individually via `add`'s covariant parameter, exactly like the
  /// element-by-element path in [_setListMember].
  ///
  /// Unlike the other mutators this one notifies unconditionally, even when the
  /// new contents happen to be the old ones: the lifecycle listeners have
  /// already torn down and rebuilt whatever they hold per element, so from an
  /// observer's point of view the list *has* been replaced.
  void _resetWithDynamic(Iterable<TomObject<dynamic>> elements) {
    // Snapshot the listener list before iterating to guard against
    // concurrent modification inside a listener callback.
    final listeners = List.of(_lifecycleListeners);
    for (final l in listeners) {
      l.onBeforeClear(this);
    }
    _detachFrom(_value);
    _value.clear();
    for (final e in elements) {
      e.addObserver(this);
      // Covariant per-element check: `e` is really an `E` even though the
      // source container was typed `List<TomObject<dynamic>>`.
      _value.add(e as E);
    }
    for (final l in listeners) {
      l.onAfterReset(this);
    }
    notifyObservers();
  }

  void add(E value) {
    value.addObserver(this);
    _value.add(value);
    notifyObservers();
  }

  void addAll(Iterable<E> iterable) {
    // Materialized once: `iterable` may be single-pass, and testing it for
    // emptiness must not consume the elements the add then needs.
    final items = List<E>.of(iterable);
    if (items.isEmpty) return;
    _attachTo(items);
    _value.addAll(items);
    notifyObservers();
  }

  Map<int, E> asMap() => _value.asMap();
  void clear() {
    if (_value.isEmpty) return;
    _detachFrom(_value);
    _value.clear();
    notifyObservers();
  }

  void fillRange(int start, int end, [E? fillValue]) {
    final before = _snapshot();
    // Before the attach, so an out-of-range call still throws — and so that an
    // empty range does not leave the list observing an element it never held.
    _detachFrom(getRange(start, end));
    _value.fillRange(start, end, fillValue);
    if (fillValue != null && end > start) {
      fillValue.addObserver(this);
    }
    _notifyIfChangedSince(before);
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
    final items = List<E>.of(iterable);
    if (items.isEmpty) {
      // Still range-checked: `insertAll(99, [])` is a caller error, not a
      // no-op, and skipping the check would hide it.
      RangeError.checkValueInInterval(index, 0, _value.length, 'index');
      return;
    }
    _value.insertAll(index, items);
    _attachTo(items);
    notifyObservers();
  }

  int lastIndexOf(E element, [int? start]) =>
      _value.lastIndexOf(element, start);
  int lastIndexWhere(bool Function(E element) test, [int? start]) =>
      _value.lastIndexWhere(test, start);
  bool remove(Object? value) {
    if (!_value.remove(value)) return false;
    if (value is TomObservable) {
      value.removeObserver(this);
    }
    notifyObservers();
    return true;
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
    // Suppress only this list's own notifications (batchSelf, not the
    // element-cascading batch) so the composite remove+insert surfaces as a
    // single consolidated notification instead of up to three, while observers
    // of the individual elements still hear about their own changes.
    //
    // batchSelf releases in a `finally`: an out-of-range index throws between
    // the two halves, and an unreleased mute would silence the list for the
    // rest of its life — a far worse outcome than the failed edit itself. It
    // also nests, so calling this from inside a caller's batch suppresses
    // without cutting that batch short.
    batchSelf(() {
      removeRange(start, end);
      insertAll(start, replacements);
    });
  }

  void retainWhere(bool Function(E element) test) {
    // No batch needed, unlike replaceRange: this delegates to a single
    // mutator, and removeWhere already notifies at most once.
    removeWhere((element) => !test(element));
  }

  void setAll(int index, Iterable<E> iterable) {
    final before = _snapshot();
    // Detach all, then re-attach whatever survives: the overwritten elements
    // are no longer in `_value` and so are left detached.
    _detachFrom(_value);
    _value.setAll(index, iterable);
    _attachTo(_value);
    _notifyIfChangedSince(before);
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    final before = _snapshot();
    _detachFrom(_value);
    _value.setRange(start, end, iterable, skipCount);
    _attachTo(_value);
    _notifyIfChangedSince(before);
  }

  void shuffle([Random? random]) {
    final before = _snapshot();
    _value.shuffle(random);
    _notifyIfChangedSince(before);
  }

  void sort([int Function(E a, E b)? compare]) {
    final before = _snapshot();
    _value.sort(compare);
    _notifyIfChangedSince(before);
  }

  List<E> sublist(int start, [int? end]) => _value.sublist(start, end);

  /// A new list of type `E` holding [source]'s elements.
  ///
  /// **The structure is copied; the elements are shared.** The two lists are
  /// independent cells from here on — adding to one does not add to the other —
  /// but they hold the *same* element instances, so both observe them and a
  /// change inside an element notifies both. That is inherent to a cast: no new
  /// elements can be manufactured, only re-typed. [source] is left untouched
  /// and fully functional; nothing is taken from it.
  ///
  /// A *live* re-typed `TomList` sharing the backing list is deliberately not
  /// offered: each container carries its own observers, so a shared structure
  /// would let one side grow the other without notifying it, and would leave
  /// elements added through one side unobserved by the other. When a live view
  /// is what you want, [cast] gives one — read-only, and a plain `List<R>`
  /// rather than an observable cell. Use [TomList.of] for this copy without the
  /// re-typing.
  ///
  /// Both type arguments must be written out — Dart takes type arguments
  /// all-or-nothing, so `S` cannot be left to inference even though [source]
  /// determines it:
  ///
  /// ```dart
  /// final ints = TomList<TomInt>()..add(TomInt(1));
  /// final widened = TomList.castFrom<TomInt, TomObject>(ints);
  /// ```
  ///
  /// Throws a `TypeError` **here**, not on a later read, if an element is not
  /// an `E`: the copy type-checks the whole sequence up front.
  static TomList<E> castFrom<S extends TomObject, E extends TomObject>(
    TomList<S> source,
  ) {
    return TomList<E>.ofList(source._value.cast<E>().toList(growable: true));
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
/// It implements no [Map] interface: the standard operations are provided, but
/// a `TomMap<K, V>` is not assignable to a `Map<K, V>`. Use [get] (which
/// returns a copy) at a boundary that insists on the `dart:core` type. Note the
/// asymmetry — [get] works, whereas [set] throws.
///
/// ## Operators
///
/// - `map[key]` - Get value for key
/// - `map[key] = value` - Set value for key
/// - `map + other` - Merge two TomMaps
/// - `map << {...}` - Replace **all** entries in one notification, returning
///   the map (see [TomMap.operator <<])
///
/// ## Notification contract
///
/// **A mutator notifies exactly once when it changed the map's contents, and
/// not at all when it left them as they were.** `remove` of an absent key,
/// `addAll({})`, `clear()` on an empty map and re-binding a key to the value it
/// already holds are all silent; `remove` of a *present* key notifies.
/// "Contents" means the key-to-value-*reference* mapping, compared by identity
/// — swapping in an equal-but-distinct value is a real change, because
/// observers hold references. A change *inside* a value is not the mutator's
/// business: it reaches observers through [onNotify].
///
/// ## Example
///
/// ```dart
/// @tomReflector
/// class Person extends TomClass {
///   final name = TomString("");
/// }
///
/// final users = TomMap<String, Person>();
/// users["john"] = Person();
///
/// // Retain the observer — it is held weakly.
/// final observer = users >> (obs) => print("Map changed!");
/// users["john"]!.name | "John Doe"; // Triggers observer
///
/// users.removeObserver(observer);
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

  /// The current key-to-value mapping, for a later [_notifyIfChangedSince].
  ///
  /// Taken by the mutators whose outcome is not knowable in advance — an
  /// `addAll` that overwrites nothing new, a `removeWhere` that matches
  /// nothing. Mutators that always change the map notify directly instead.
  Map<K, V> _snapshot() => Map<K, V>.of(_value);

  /// Notifies observers only if the mapping differs from [before].
  ///
  /// Compared by identity, not equality: observers hold value references, so
  /// swapping in an equal-but-distinct value is a real change. A change
  /// *inside* a value is not this method's business — it reaches observers
  /// through [onNotify].
  ///
  /// Equal sizes plus every old key still bound to the same object implies the
  /// key sets are equal too: a dropped key would have to be balanced by a new
  /// one, and the dropped key's lookup then returns `null`.
  void _notifyIfChangedSince(Map<K, V> before) {
    if (before.length != _value.length) {
      notifyObservers();
      return;
    }
    for (final entry in before.entries) {
      if (!identical(_value[entry.key], entry.value)) {
        notifyObservers();
        return;
      }
    }
  }

  /// Throws [TomObservableException] - direct value setting is not allowed.
  ///
  /// Use [add], `[]=` operator, or [addAll] to modify the map.
  @override
  Map<K, V> set(Map<K, V> value) {
    throw TomObservableException(
      "observable.map_state.set_not_allowed",
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

  /// Muting a map mutes its values, so that a batch touching several entries
  /// surfaces as one notification from the map.
  @override
  Iterable<TomObservable> get muteCascadeTargets => _value.values;

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

  /// Replaces every entry with [newMap] and returns this map.
  ///
  /// The map counterpart of [TomList.operator <<], with the same contract:
  /// [set] throws on a map, so this is the operator form of a wholesale swap.
  /// It detaches the outgoing values, attaches the incoming ones, and emits
  /// **one** notification for the exchange rather than one per entry.
  ///
  /// ```dart
  /// final scores = TomMap<String, TomInt>();
  /// scores << {'ada': TomInt(10), 'bob': TomInt(8)};   // one notification
  /// ```
  @override
  TomMap<K, V> operator <<(Map<K, V> newMap) {
    final before = _snapshot();
    _detachFrom(_value.values);
    _attachTo(newMap.values);
    _value = Map<K, V>.of(newMap);
    _notifyIfChangedSince(before);
    return this;
  }

  /// Identity, **not** contents: a map equals only itself.
  ///
  /// The rule, and the reasoning behind it, are the same as for
  /// [TomList.operator ==] — a mutable cell cannot carry a content-based
  /// [hashCode] without going missing from the `Set` it was put in, and
  /// observers register per instance, so two maps with equal entries are
  /// different cells. Every other observable in this library inherits the same
  /// identity equality from `Object`.
  ///
  /// To compare contents, unwrap the values; they are observables in their own
  /// right and compare by identity too:
  ///
  /// ```dart
  /// bool sameContents(TomMap<String, TomInt> a, TomMap<String, TomInt> b) =>
  ///     a.length == b.length &&
  ///     a.keys.every((k) => b.containsKey(k) && ~a[k]! == ~b[k]!);
  /// ```
  @override
  bool operator ==(Object other) => identical(this, other);

  /// The number of key-value pairs in the map.
  int get length => _value.length;

  /// Widens a deserialized [raw] number to `double` when this map holds
  /// doubles, leaving every other value untouched.
  ///
  /// Exists because `V` is only in scope here: [TomClass._setMapMember] knows
  /// the raw JSON value but not the value type. See
  /// [TomObject._widenForDoubleTarget] for the rule itself.
  dynamic _widenValue(dynamic raw) => TomObject._widenForDoubleTarget<V>(raw);

  /// Builds the value this map should hold for [raw]; the map-side counterpart
  /// of `TomList._elementFrom`.
  TomObject<dynamic> _valueFrom(dynamic raw) =>
      TomObject._createForTarget<V>(raw);

  /// Whether this map's value type is the untyped base [TomObject].
  ///
  /// The map-side counterpart of `TomList._hasUntypedElements`; see there for
  /// why [TomClass._setMapMember] has to ask before consulting reflection.
  bool get _hasUntypedValues => <TomObject<dynamic>>[] is List<V>;

  /// The identity hash, and therefore **stable across every mutation**.
  ///
  /// Agrees with [operator ==]; see [TomList.hashCode] for why a hash that
  /// tracked the contents would be actively harmful here.
  @override
  int get hashCode => identityHashCode(this);

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
  /// Re-binding a key to the value it already holds changes nothing and is
  /// therefore silent.
  void add(K key, V value) {
    final existing = _value[key];
    if (identical(existing, value)) return;
    existing?.removeObserver(this);
    value.addObserver(this);
    _value[key] = value;
    notifyObservers();
  }

  void addAll(Map<K, V> other) {
    final before = _snapshot();
    // Detach all, then re-attach whatever survives: values displaced by `other`
    // are no longer in `_value` and so are left detached.
    _detachFrom(_value.values);
    _value.addAll(other);
    _attachTo(_value.values);
    _notifyIfChangedSince(before);
  }

  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final before = _snapshot();
    _detachFrom(_value.values);
    _value.addEntries(newEntries);
    _attachTo(_value.values);
    _notifyIfChangedSince(before);
  }

  /// A **read-only** re-typed view of this map.
  ///
  /// `Map.cast` alone returns a writable view, so `map.cast<Object, TomObject>()
  /// .remove(k)` would drop an entry without detaching the value's observer and
  /// without notifying. See [TomList.cast].
  Map<RK, RV> cast<RK, RV>() => UnmodifiableMapView(_value.cast<RK, RV>());

  void clear() {
    if (_value.isEmpty) return;
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

  /// Removes [key] and returns its value, or `null` if the key was absent.
  ///
  /// A removal detaches the value and notifies; an absent key changes nothing
  /// and is silent. `V` is non-nullable, so a `null` from the underlying remove
  /// means "was not there" and nothing else.
  V? remove(K? key) {
    if (key == null) return null;
    final value = _value.remove(key);
    if (value == null) return null;
    value.removeObserver(this);
    notifyObservers();
    return value;
  }

  void removeWhere(bool Function(K key, V value) test) {
    final before = _snapshot();
    _detachFrom(_value.values);
    _value.removeWhere(test);
    _attachTo(_value.values);
    _notifyIfChangedSince(before);
  }

  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final existing = _value[key];
    if (existing != null) {
      // Suppress only this map's own notifications across the callback
      // (batchSelf, not the value-cascading batch): the callback is free to
      // mutate the value *and* return a replacement, and the caller made one
      // call, so it gets one notification. batchSelf releases in a `finally` —
      // a throwing callback must not leave the map silent for the rest of its
      // life — and nests, so an enclosing batch survives this call.
      return batchSelf(() {
        final newValue = update(existing);
        if (identical(newValue, existing)) return existing;
        existing.removeObserver(this);
        newValue.addObserver(this);
        _value[key] = newValue;
        notifyObservers();
        return newValue;
      });
    }
    if (ifAbsent == null) {
      throw TomObservableException(
        "observable.map_state.update_key_not_found_no_ifabsent",
        "Map doesn't contain key $key and no ifAbsent method provided",
      );
    }
    final newValue = ifAbsent();
    newValue.addObserver(this);
    _value[key] = newValue;
    notifyObservers();
    return newValue;
  }

  void updateAll(V Function(K key, V value) update) {
    final before = _snapshot();
    // See [update] for the mute: the callbacks may mutate values in place as
    // well as replace them, and updateAll is one call.
    batchSelf(() {
      _value.updateAll((key, value) {
        final newValue = update(key, value);
        if (!identical(newValue, value)) {
          value.removeObserver(this);
          newValue.addObserver(this);
        }
        return newValue;
      });
      _notifyIfChangedSince(before);
    });
  }

  /// A new map of type `K2`/`V2` holding [source]'s entries.
  ///
  /// **The structure is copied; the values are shared.** Same contract as
  /// [TomList.castFrom] — the two maps are independent cells, but they hold the
  /// same value instances, so both observe them and a change inside a value
  /// notifies both. [source] is left untouched. For a live view instead, [cast]
  /// gives one — read-only, and a plain `Map<RK, RV>` rather than an observable
  /// cell. Use [TomMap.of] for this copy without the re-typing.
  ///
  /// All four type arguments must be written out, since Dart takes type
  /// arguments all-or-nothing:
  ///
  /// ```dart
  /// final scores = TomMap<String, TomInt>();
  /// final widened = TomMap.castFrom<String, TomInt, String, TomObject>(scores);
  /// ```
  ///
  /// Throws a `TypeError` **here**, not on a later read, if a key or value does
  /// not have the target type: the copy type-checks every entry up front.
  static TomMap<K2, V2> castFrom<
    K,
    V extends TomObject,
    K2,
    V2 extends TomObject
  >(TomMap<K, V> source) {
    return TomMap<K2, V2>.ofMap(Map<K2, V2>.of(source._value.cast<K2, V2>()));
  }
}
