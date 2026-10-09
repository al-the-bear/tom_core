import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/client_exceptions.dart';

/// Thrown when a [TomProperty] cannot resolve its configuration key.
///
/// One type, two conditions, told apart by `key` — the same shape the kernel's
/// own resources module uses for its providers. The two call for different
/// repairs, so the distinction is worth matching on:
///
/// | `key` | Condition |
/// | ----- | --------- |
/// | `resources.property.not_configured` | The key resolves to nothing — absent, or present with a `null` value — and the property declared no default. The message says which. |
/// | `resources.property.type_mismatch` | The key holds a value that cannot be cast to the property's `T`. |
///
/// Both are raised during construction, so catching them means wrapping the
/// declaration, not the read. `parameters` carries the key — and, for a type
/// mismatch, the value and the type it was wanted as — for a log formatter to
/// render; `rootException` carries the `TypeError` the cast raised, which is
/// the only record of the value's *actual* type, since the message names only
/// the type that was expected.
class TomPropertyException extends TomClientException {
  /// Creates a property-resolution failure. See `TomException` for the meaning
  /// of each argument.
  TomPropertyException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A typed, eagerly-resolved value read from the kernel configuration
/// resources.
///
/// `TomProperty<T>` reads the value for [key] from the application
/// [TomConfigResourceProvider] **once, at construction**, and caches it. Read
/// the cached value with [get] or the `~` operator. Use the typed subclasses
/// ([TomStringProperty], [TomIntProperty], [TomDoubleProperty],
/// [TomBoolProperty]) for the four non-nullable value types they name, rather
/// than instantiating the generic over those types. **When [T] is nullable the
/// generic is the intended form** — each subclass closes over a non-nullable
/// type, so none of them can express an optional value.
///
/// ```dart
/// // resolves "app.title" from config at construction:
/// final title = TomStringProperty('app.title');
/// final text = ~title; // or title.get()
///
/// // fall back to a default when the key is absent:
/// final retries = TomIntProperty.withDefault('app.retries', 3);
///
/// // an optional value: no subclass has a nullable T, so use the generic:
/// final region = TomProperty<String?>.withDefault('app.region', null);
/// ```
///
/// **Resolution rules (at construction):** a single config lookup answers both
/// whether the key is present and what it holds. A resolved value is cast to
/// [T]; otherwise the [TomProperty.withDefault] default is used; a key that is
/// both absent and has no default throws. Both failures raise
/// [TomPropertyException] — see it for the two `key` codes.
///
/// **A configured whole number fills a `double`.** No configuration file can
/// say "double" — `rate: 2` in YAML and `"rate": 2` in JSON both decode to an
/// `int` — so a cast that fails on an `int` where [T] accepts a `double` widens
/// instead of throwing, matching the server's `TomConfig` and the reflected
/// path that fills a declared `double` field. It does not narrow (`2.5` under
/// [TomIntProperty] is still a mismatch, because narrowing needs a rounding
/// policy) and it does not parse (`'2'` is still a mismatch). It is reached
/// only *after* a cast has failed, so `TomProperty<num>` over a configured `2`
/// still holds an `int`.
///
/// **Key resolution:** [key] reaches the provider unchanged, so a property
/// inherits its dot notation over nested maps. `'app.db.host'` resolves either
/// through nested `app` / `db` maps or as a flat entry of that literal name;
/// the nested walk runs first and the flat lookup is its fallback, so a config
/// carrying both spellings answers with the nested one. Descent stops at the
/// last segment, which makes an interior node a value in its own right — a
/// `TomProperty<Map<String, dynamic>>` holds a subtree, and is the second place
/// the generic is the intended form. A key configured with no value counts as
/// absent, so a configured `null` never overrides a non-null default; where
/// that distinction matters, read the provider's public `resources` map
/// directly.
///
/// **Structured values: the generic, with the dynamic element type.** The four
/// typed subclasses are scalar, and there is deliberately no `TomListProperty`
/// or `TomMapProperty` — a list is `TomProperty<List<dynamic>>` and a map
/// `TomProperty<Map<String, dynamic>>`. The element type has to be `dynamic`:
/// every configuration format arrives through a decoder and no decoder produces
/// a narrower one, so `TomProperty<List<String>>` fails the cast on a
/// configured `hosts: [a, b]`. It is worth knowing that it fails *selectively*
/// — a hand-written config map in a test does yield `List<String>` and the
/// construction passes there — so the narrow form is a property that works
/// until it is loaded from a file. Narrow at the call site instead, with
/// `.cast<String>()` or `List<String>.from(...)`.
///
/// **A structured value is held by reference.** A scalar is copied, so every
/// other property here is a snapshot in the strong sense; a list or map is the
/// provider's own object, cached. Mutating what one was handed edits the
/// application's configuration for every later reader of that key. Copy it if
/// it is going to be modified — `List.from` / `Map.of` — which is the same
/// `cast` or `from` call the element type already wanted.
///
/// **Eager and immutable:** the value is captured at construction and never
/// re-read, so later config changes are not reflected. Construct the property
/// after the config providers are populated.
///
/// The ordering is a contract, and it is enforced on one side only. With no
/// provider installed there is nothing to resolve and the construction throws
/// the kernel's `resources.config_provider.not_installed` — at the declaration,
/// which is where a bootstrap-order mistake is cheapest to find. A provider
/// *replaced* after a property is built is silent, and the property keeps what
/// it resolved; nothing reports that and nothing can, because
/// `TomConfigResourceProvider.setAppConfigProvider` announces nothing by
/// design — configuration is captured by its consumers when they are built, so
/// a revision counter would notify values that have already been taken. A
/// default follows the same rule: one taken because the key was absent *is* the
/// resolution, and a later provider carrying the key does not displace it.
///
/// An application that replaces configuration at a session boundary rebuilds
/// what depends on it, so the properties constructed afterwards are the new
/// ones. A value that has to be live is not a property: read it from
/// `TomConfigResourceProvider.getAppConfig()` at the point of use, and pay the
/// lookup each time. A value a *user* changes is not configuration — see
/// `TomClientConfiguration`, which layers a user or device preference over an
/// install's value.
class TomProperty<T> {
  /// The application config resources.
  ///
  /// Resolved on use rather than held, so a property declared in a library
  /// that loads before the provider is installed still sees it — the read
  /// happens in the constructor body, not at field-initialiser time.
  TomConfigResourceProvider get _config =>
      TomConfigResourceProvider.getAppConfig();

  late final T _value;
  final String _propertyKey;

  /// The fallback value, assigned only by [TomProperty.withDefault]. Guarded by
  /// [_hasDefault] — never read unless a default was actually supplied, so a
  /// nullable `T` default of `null` is honoured rather than mistaken for
  /// "no default".
  late final T _defaultValue;

  /// Whether a default was supplied. This — not `_defaultValue != null` —
  /// drives the fallback branch, so a no-default construction reaches the
  /// descriptive obligatory-key error instead of reading the unassigned
  /// `late` default field (which threw `LateInitializationError`), and an
  /// explicit `null` default over a nullable `T` is used as given.
  final bool _hasDefault;

  /// Resolves [key] from config at construction; throws if absent.
  TomProperty(String key) : _propertyKey = key, _hasDefault = false {
    _getValue();
  }

  /// Resolves [key] from config at construction, falling back to [value] when
  /// the key is absent.
  TomProperty.withDefault(String key, T value)
    : _propertyKey = key,
      _defaultValue = value,
      _hasDefault = true {
    _getValue();
  }

  void _getValue() {
    // One lookup, not two. `getObjectOrNull` answers "is it there" and "what
    // is it" together, where the older `exists`-then-`getObject` pair asked the
    // store the same question twice and the failure report asked a third time
    // — on the path whose premise is that the store has already answered.
    // Anything more expensive than a map behind the provider makes that
    // wasteful; anything less reliable makes it dangerous, because a read that
    // throws while describing a failure replaces the diagnosis with its own
    // exception.
    //
    // A `null` here means *absent*: `getObjectOrNull` returns null both for a
    // key that was never written and for one configured with no value, and the
    // module treats them the same — `app.region:` in a YAML file does not
    // satisfy an obligatory property.
    final configured = _config.getObjectOrNull(_propertyKey);

    if (configured != null) {
      try {
        _value = configured as T;
      } on TypeError catch (error, stack) {
        // Narrow on purpose. Both arms below assume a failed `as` — the
        // widening reads the failure as "aimed at a double", the throw reports
        // it as a type mismatch — and only a `TypeError` from this one
        // expression is evidence of that. A wider catch would put both
        // readings in front of failures they never diagnosed, sending the
        // reader to look at their type declarations for a fault that is
        // somewhere else entirely.
        //
        // Catching an *Error* is deliberate, and is why the clause cannot be
        // `on Exception`. A `TypeError` normally signals a bug, but this one is
        // raised by data the operator wrote, so it is a configuration fault and
        // has to become a reportable exception rather than reach the caller as
        // an Error.
        if (configured is int && 0.0 is T) {
          // A configuration file cannot say "double": `rate: 2` in YAML and
          // `"rate": 2` in JSON both decode to an int, so a declared
          // `TomDoubleProperty('rate')` would fail on a value that is exactly
          // what the operator meant. The server's `TomConfig` widens the same
          // way, and the reflected path widens onto a declared double field —
          // without this, one file could fill a field and fail the matching
          // property. The converse is deliberately absent, for the reason the
          // reflector gives for not having it either: narrowing needs a
          // rounding policy, and truncating 2.5 loses what the operator wrote.
          //
          // Why this sits *after* the failed cast rather than in front of it:
          // `0.0 is T` is also true for `num`, `Object` and `dynamic`, where
          // `2 as T` already succeeds and the int must survive as an int. Only
          // a cast that has actually failed can have been aimed at a double.
          _value = configured.toDouble() as T;
        } else {
          // The caught error is chained rather than summarised away. The
          // message names the key, the wanted type and the value, which is
          // enough for a scalar mismatch — but not for a generic one: a YAML
          // `hosts: [a, b]` read as `List<String>` fails on the *element*
          // type, and the message reports `with value [a, b]`, which is what
          // the operator wrote and looks perfectly valid. Only the `TypeError`
          // says `List<dynamic> is not a subtype of List<String>`.
          throw TomPropertyException(
            'resources.property.type_mismatch',
            "Could not set property of type $T from value of property $_propertyKey with value $configured",
            parameters: {
              'key': _propertyKey,
              'expectedType': '$T',
              'value': configured,
            },
            rootException: error,
            stack: stack,
          );
        }
      }
    } else if (_hasDefault) {
      _value = _defaultValue;
    } else if (_isConfiguredWithoutValue()) {
      throw TomPropertyException(
        'resources.property.not_configured',
        "Obligatory resource $_propertyKey is configured without a value",
        parameters: {'key': _propertyKey},
      );
    } else {
      throw TomPropertyException(
        'resources.property.not_configured',
        "Obligatory resource $_propertyKey not found in configuration resources",
        parameters: {'key': _propertyKey},
      );
    }
  }

  /// Whether the key is in the config map with a `null` value — `app.region:`
  /// in a YAML file — rather than absent.
  ///
  /// Resolution treats the two alike, because the kernel's lookup cannot tell
  /// them apart. The *report* must, or it tells the operator the key was not
  /// found and sends them to the one line of their file that is already there.
  ///
  /// Asked of the provider's own map, on the failure path only, so a
  /// successful resolution still reads the provider once. It never throws: a
  /// failure report that threw while describing itself would replace the
  /// diagnosis with its own exception.
  bool _isConfiguredWithoutValue() {
    try {
      final resources = _config.resources;
      if (resources.containsKey(_propertyKey)) {
        return resources[_propertyKey] == null;
      }
      final tree = lookupObjectInTree(resources, _propertyKey);
      return tree.found && tree.value == null;
    } on Object {
      return false;
    }
  }

  /// Returns the resolved, cached value.
  T get() {
    return _value;
  }

  /// Returns the resolved, cached value (operator form of [get]).
  T operator ~() {
    return _value;
  }
}

/// A [TomProperty] holding a [String] config value.
class TomStringProperty extends TomProperty<String> {
  /// Resolves the string at [key] from config; throws if absent.
  TomStringProperty(super.key);

  /// Resolves the string at [key], falling back to [value] when absent.
  TomStringProperty.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomProperty] holding an [int] config value.
class TomIntProperty extends TomProperty<int> {
  /// Resolves the int at [key] from config; throws if absent.
  TomIntProperty(super.key);

  /// Resolves the int at [key], falling back to [value] when absent.
  TomIntProperty.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomProperty] holding a [double] config value.
///
/// A configured whole number is widened rather than refused — see
/// [TomProperty] for why, and for the two conversions this is not.
class TomDoubleProperty extends TomProperty<double> {
  /// Resolves the double at [key] from config; throws if absent.
  TomDoubleProperty(super.key);

  /// Resolves the double at [key], falling back to [value] when absent.
  TomDoubleProperty.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomProperty] holding a [bool] config value.
class TomBoolProperty extends TomProperty<bool> {
  /// Resolves the bool at [key] from config; throws if absent.
  TomBoolProperty(super.key);

  /// Resolves the bool at [key], falling back to [value] when absent.
  TomBoolProperty.withDefault(super.key, super.value) : super.withDefault();
}
