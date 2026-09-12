import '../little_things/server_exception.dart';
import 'base_server_configuration.dart';

/// A configuration property could not be resolved to the type asked for.
///
/// Thrown by [TomConfig] when the configured value fails the cast to `T` and
/// the `int`→`double` widening does not apply. Carries the [TypeError] that
/// the cast raised as `rootException`, together with its stack trace — the
/// message names the key, the wanted type and the value, which is enough for a
/// scalar mismatch but not for a generic one, where only the chained
/// `TypeError` names the subtype relation that actually failed.
///
/// `parameters` carries the `key`, `type` and `value` separately, so a handler
/// can report them without parsing the message.
///
/// This is the only *exception* the resolution path raises. An obligatory key
/// with no default throws a bare `String` instead, which no `on Exception
/// catch` will see — see `doc/configuration.md` under *Not Yet Implemented*.
class TomConfigurationException extends TomServerException {
  /// Creates a configuration resolution failure.
  TomConfigurationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

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
///    throws a [TomConfigurationException] naming the key, type and value, and
///    chaining the [TypeError] the cast raised).
/// 2. Otherwise, if a default was supplied via [TomConfig.withDefault], the
///    default is used.
/// 3. Otherwise the property is considered obligatory and construction throws.
///
/// One widening applies in branch 1: an `int` resolves as a `double` when [T]
/// is `double` (or `double?`), so `rate: 2` and `rate: 2.0` mean the same
/// thing. A configuration file cannot say "double" — both YAML `rate: 2` and
/// JSON `"rate": 2` decode to an `int` — and the reflected path that fills a
/// configuration object's *fields* widens the same way, so a file that fills a
/// declared `double` field also satisfies the matching [TomDoubleConfig]. The
/// converse does not hold: a decimal is still refused for an `int`, because
/// narrowing would need a rounding policy and truncating `2.5` would discard
/// what the operator wrote.
///
/// The provider is the **only** source read. The OS environment, the `.env`
/// file and the command line are *not* a fourth branch: they are merged by
/// [TomBaseServerConfiguration.getDefaultValues] into a **copy** of the
/// provider's resources, and that copy populates a configuration object's
/// *fields* — it is never installed back into the provider, so merging one
/// server's arguments cannot leak into every later lookup in the process. To
/// read such a value here, install the merged map as the provider first:
///
/// ```dart
/// TomServerConfigResourceProvider.setServerConfigProvider(
///   TomServerConfigResourceProvider.from(
///     TomBaseServerConfiguration.getDefaultValues(args).cast<String, dynamic>(),
///   ),
/// );
/// ```
///
/// Note that [TomConfig.withDefault] fails *silently* against an unmerged key:
/// an absent key and a key the environment supplied but nobody installed are
/// indistinguishable here, so the default wins and nothing throws.
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
    final provider = TomServerConfigResourceProvider.getServerConfig();
    // Before anything else: resolving against the placeholder
    // `getServerConfig` creates when nothing has been installed is an ordering
    // mistake, not a configuration one, and the two report differently. Taking
    // the placeholder's answer would give a defaulted property its default and
    // an obligatory one a throw naming the *key* — three ways of hiding the
    // same fact, that the configuration did not exist yet.
    if (provider.isUnconfiguredPlaceholder) {
      throw TomConfigurationException(
        'configuration.tom_config.no_provider_installed',
        "Property '$_propertyKey' was resolved before a configuration "
            'provider was installed. A TomConfig reads its value once, at '
            'construction, so it must be built after '
            'TomServerConfigResourceProvider.setServerConfigProvider (or after '
            'a TomBaseServerConfiguration, which installs one) — not as a '
            'static or a field initialiser, which run at class-load time.',
        parameters: {'key': _propertyKey},
      );
    }
    if (provider.exists(_propertyKey)) {
      final raw = provider.get(_propertyKey);
      // `on TypeError` rather than a bare `catch`: a failed `as` is the only
      // thing this `try` means to handle, and both arms below assume it — the
      // widening treats the failure as "aimed at a double", the throw reports
      // it as a type mismatch. A bare catch would apply that reading to
      // anything else that ever came to be thrown here.
      //
      // Catching an *Error* is deliberate, and is why the clause cannot be
      // `on Exception`. A TypeError normally signals a bug, but this one is
      // raised by data the operator wrote, so it is a configuration fault and
      // has to become a reportable exception rather than reach the caller as
      // an Error.
      try {
        _value = raw as T;
      } on TypeError catch (error, stackTrace) {
        // A configuration file cannot say "double": `rate: 2` in YAML and
        // `"rate": 2` in JSON both decode to an int. The reflected path already
        // widens such a value onto a declared double field, so widen it here
        // too — otherwise one file could fill a field and fail the matching
        // lookup. The converse is deliberately absent, for the reason the
        // reflector gives for not having it either: narrowing needs a rounding
        // policy, and truncating 2.5 loses what the operator wrote.
        //
        // Why this sits *after* the failed cast rather than in front of it:
        // `0.0 is T` is also true for `num`, `Object` and `dynamic`, where
        // `2 as T` already succeeds and the int must survive as an int. Only a
        // cast that has actually failed can have been aimed at a double.
        if (raw is int && 0.0 is T) {
          _value = raw.toDouble() as T;
        } else {
          // The caught error is chained rather than summarised away. The
          // message below names the key, the wanted type and the value, which
          // is enough for a scalar mismatch — but not for a generic one: a
          // YAML `hosts: [a, b]` read as `List<String>` fails on the *element*
          // type, and the message reports `with value [a, b]`, which is what
          // the operator wrote and looks perfectly valid. Only the TypeError
          // says `List<dynamic> is not a subtype of List<String>`.
          throw TomConfigurationException(
            "configuration.tom_config.property_type_mismatch",
            "Could not set property of type $T from value of property $_propertyKey with value $raw",
            parameters: {'key': _propertyKey, 'type': '$T', 'value': raw},
            rootException: error,
            stack: stackTrace,
          );
        }
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
