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
/// | `resources.property.not_configured` | The key is absent and the property declared no default. |
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
/// **Eager and immutable:** the value is captured at construction and never
/// re-read, so later config changes are not reflected. Construct the property
/// after the config providers are populated.
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
  TomProperty(String key)
      : _propertyKey = key,
        _hasDefault = false {
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
        // Narrow on purpose. The message below asserts that a cast failed, and
        // only a `TypeError` from this one expression is evidence of that; a
        // wider catch would put that assertion in front of failures it never
        // diagnosed, sending the reader to look at their type declarations for
        // a fault that is somewhere else entirely.
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
    } else if (_hasDefault) {
      _value = _defaultValue;
    } else {
      throw TomPropertyException(
        'resources.property.not_configured',
        "Obligatory resource $_propertyKey not found in configuration resources",
        parameters: {'key': _propertyKey},
      );
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
