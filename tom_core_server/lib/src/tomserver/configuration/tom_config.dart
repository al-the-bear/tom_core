import 'base_server_configuration.dart';

class TomConfig<T> {
  T? _value;
  late String _propertyKey;
  T? _defaultValue;

  TomConfig(String key) {
    _propertyKey = key;
    _getValue();
  }

  TomConfig.withDefault(String key, T value) {
    _defaultValue = value;
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
    } else if (_defaultValue != null) {
      _value = _defaultValue;
    } else {
      throw ("Obligatory resource $_propertyKey not found in configuration resources");
    }
  }

  T? get() {
    return _value;
  }

  T? operator ~() {
    return _value;
  }
}

class TomStringConfig extends TomConfig<String> {
  TomStringConfig(super.key);

  TomStringConfig.withDefault(super.key, super.value) : super.withDefault();
}

class TomIntConfig extends TomConfig<int> {
  TomIntConfig(super.key);

  TomIntConfig.withDefault(super.key, super.value) : super.withDefault();
}

class TomDoubleConfig extends TomConfig<double> {
  TomDoubleConfig(super.key);

  TomDoubleConfig.withDefault(super.key, super.value) : super.withDefault();
}

class TomBoolConfig extends TomConfig<bool> {
  TomBoolConfig(super.key);

  TomBoolConfig.withDefault(super.key, super.value) : super.withDefault();
}
