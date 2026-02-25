import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomProperty<T> {
  String Function(String) get t =>
      TomTextResourceProvider.getAppResources().getText;
  bool Function(String) get translationExists =>
      TomTextResourceProvider.getAppResources().exists;
  Object Function(String) get c =>
      TomConfigResourceProvider.getAppConfig().getText;
  bool Function(String) get configExists =>
      TomConfigResourceProvider.getAppConfig().exists;

  late T _value;
  late String _propertyKey;
  late T _defaultValue;

  TomProperty(String key) {
    _propertyKey = key;
    _getValue();
  }

  TomProperty.withDefault(String key, T value) {
    _defaultValue = value;
    _propertyKey = key;
    _getValue();
  }

  void _getValue() {
    if (configExists(_propertyKey)) {
      try {
        _value = c(_propertyKey) as T;
      } catch (exception) {
        throw Exception(
          "Could not set property of type $T from value of property $_propertyKey with value ${c(_propertyKey)}",
        );
      }
    } else if (_defaultValue != null) {
      _value = _defaultValue;
    } else {
      throw ("Obligatory resource $_propertyKey not found in configuration resources");
    }
  }

  T get() {
    return _value;
  }

  T operator ~() {
    return _value;
  }
}

class TomStringProperty extends TomProperty<String> {
  TomStringProperty(super.key);

  TomStringProperty.withDefault(super.key, super.value) : super.withDefault();
}

class TomIntProperty extends TomProperty<int> {
  TomIntProperty(super.key);

  TomIntProperty.withDefault(super.key, super.value) : super.withDefault();
}

class TomDoubleProperty extends TomProperty<double> {
  TomDoubleProperty(super.key);

  TomDoubleProperty.withDefault(super.key, super.value) : super.withDefault();
}

class TomBoolProperty extends TomProperty<bool> {
  TomBoolProperty(super.key);

  TomBoolProperty.withDefault(super.key, super.value) : super.withDefault();
}
