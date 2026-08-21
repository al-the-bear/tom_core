import 'base_server_configuration.dart';

/// A typed, eagerly-resolved view of a single configuration property.
///
/// The value is read **once at construction** from the active
/// [TomServerConfigResourceProvider] and cached; later changes to the provider
/// are not observed by an already-constructed `TomConfig`. The key may be a
/// dotted path into a nested configuration tree (resolved by the provider's
/// `get`/`exists`).
///
/// Resolution order at construction:
/// 1. If the provider has the [key], its value is cast to [T] (a failed cast
///    throws an [Exception] naming the key, type, and value).
/// 2. Otherwise, if a default was supplied via [TomConfig.withDefault], the
///    default is used.
/// 3. Otherwise the property is considered obligatory and construction throws.
///
/// A key configured explicitly as `null` takes branch 1, not branch 2: the
/// provider reports it as present, because an explicit `null` is a deliberate
/// act and a default exists to cover an *absent* key (the same reason a
/// nullable `null` default is honoured). So `TomConfig<int?>` reads
/// it as `null`, while `TomConfig<int>` fails the cast and throws naming the
/// key. Failing loudly is intended: silently substituting the default would
/// discard the very setting the operator wrote.
///
/// Prefer the typed subclasses ([TomStringConfig], [TomIntConfig],
/// [TomDoubleConfig], [TomBoolConfig]) where the type is known up front.
///
/// ```dart
/// final port = TomIntConfig.withDefault('server.port', 8080).get();
/// ```
class TomConfig<T> {
  T? _value;
  late String _propertyKey;
  T? _defaultValue;

  /// Whether a default was supplied via [TomConfig.withDefault]. Tracked
  /// separately from `_defaultValue != null` so a *nullable* `null` default is
  /// honoured rather than treated as "no default".
  bool _hasDefault = false;

  /// Resolves an **obligatory** property [key] from the active provider.
  ///
  /// Throws if the key is absent (no default to fall back on) or if its value
  /// cannot be cast to [T].
  TomConfig(String key) {
    _propertyKey = key;
    _getValue();
  }

  /// Resolves property [key], falling back to [value] when the key is absent.
  TomConfig.withDefault(String key, T value) {
    _defaultValue = value;
    _hasDefault = true;
    _propertyKey = key;
    _getValue();
  }

  void _getValue() {
    if (TomServerConfigResourceProvider.getServerConfig().exists(
      _propertyKey,
    )) {
      try {
        _value =
            TomServerConfigResourceProvider.getServerConfig().get(_propertyKey)
                as T;
      } catch (exception) {
        throw Exception(
          "Could not set property of type $T from value of property $_propertyKey with value ${TomServerConfigResourceProvider.getServerConfig().get(_propertyKey)}",
        );
      }
    } else if (_hasDefault) {
      _value = _defaultValue;
    } else {
      throw ("Obligatory resource $_propertyKey not found in configuration resources");
    }
  }

  /// Returns the resolved value (or `null` only for a nullable [T] default).
  T? get() {
    return _value;
  }

  /// Shorthand for [get]: `~config` returns the resolved value.
  T? operator ~() {
    return _value;
  }
}

/// A [TomConfig] specialised to `String`.
class TomStringConfig extends TomConfig<String> {
  /// Resolves an obligatory `String` property [key].
  TomStringConfig(super.key);

  /// Resolves a `String` property [key], defaulting to [value] when absent.
  TomStringConfig.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomConfig] specialised to `int`.
class TomIntConfig extends TomConfig<int> {
  /// Resolves an obligatory `int` property [key].
  TomIntConfig(super.key);

  /// Resolves an `int` property [key], defaulting to [value] when absent.
  TomIntConfig.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomConfig] specialised to `double`.
class TomDoubleConfig extends TomConfig<double> {
  /// Resolves an obligatory `double` property [key].
  TomDoubleConfig(super.key);

  /// Resolves a `double` property [key], defaulting to [value] when absent.
  TomDoubleConfig.withDefault(super.key, super.value) : super.withDefault();
}

/// A [TomConfig] specialised to `bool`.
class TomBoolConfig extends TomConfig<bool> {
  /// Resolves an obligatory `bool` property [key].
  TomBoolConfig(super.key);

  /// Resolves a `bool` property [key], defaulting to [value] when absent.
  TomBoolConfig.withDefault(super.key, super.value) : super.withDefault();
}
