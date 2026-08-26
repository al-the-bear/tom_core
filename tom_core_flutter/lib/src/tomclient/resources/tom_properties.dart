import 'package:tom_core_kernel/tom_core_kernel.dart';

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
/// **Resolution rules (at construction):** if the config key exists its value
/// is cast to [T]; otherwise the [TomProperty.withDefault] default is used; a
/// key that is both absent and has no default throws.
///
/// **Eager and immutable:** the value is captured at construction and never
/// re-read, so later config changes are not reflected. Construct the property
/// after the config providers are populated.
class TomProperty<T> {
  /// Config-value lookup from the application config resources.
  Object Function(String) get _c =>
      TomConfigResourceProvider.getAppConfig().getText;

  /// Whether a config value exists for the given key.
  bool Function(String) get _configExists =>
      TomConfigResourceProvider.getAppConfig().exists;

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
    if (_configExists(_propertyKey)) {
      try {
        _value = _c(_propertyKey) as T;
      } catch (exception) {
        throw Exception(
          "Could not set property of type $T from value of property $_propertyKey with value ${_c(_propertyKey)}",
        );
      }
    } else if (_hasDefault) {
      _value = _defaultValue;
    } else {
      throw Exception(
        "Obligatory resource $_propertyKey not found in configuration resources",
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
