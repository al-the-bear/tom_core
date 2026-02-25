import 'package:flutter/material.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomField<T> extends TomObject<T> {
  String Function(String) get t =>
      TomTextResourceProvider.getAppResources().getText;
  bool Function(String) get translationExists =>
      TomTextResourceProvider.getAppResources().exists;
  Object Function(String) get c =>
      TomConfigResourceProvider.getAppConfig().getText;
  bool Function(String) get configExists =>
      TomConfigResourceProvider.getAppConfig().exists;

  String fieldName;
  String formName;
  T initialValue;
  bool obscureText;

  TomField(
    this.formName,
    this.fieldName,
    this.initialValue, {
    this.obscureText = false,
    T Function(String)? valueConverter,
    String Function(T)? valueToTextConverter,
    String? Function(String)? inputValidator,
    String? Function(String)? valueValidator,
  }) : super(initialValue) {
    if (valueToTextConverter != null) {
      _valueToTextConverter = valueToTextConverter;
    }
    _textEditingController = TextEditingController(
      text: _valueToTextConverter(initialValue),
    );
    if (inputValidator != null) {
      _inputValidators.add(inputValidator);
    }
    String patternKey = "$formName.$fieldName.pattern";
    if (translationExists(patternKey)) {
      _inputValidators.add((String value) {
        if (RegExp(t(patternKey)).hasMatch(value)) {
          return null;
        } else {
          return t("$formName.$fieldName.errors.pattern");
        }
      });
    }
    if (valueValidator != null) {
      _valueValidators.add(valueValidator);
    }
    if (valueConverter != null) {
      _valueConverter = valueConverter;
    }
    _textEditingController.addListener(() {
      var value = _textEditingController.value.text;
      bool valid = true;
      String? error;
      for (var inputValidator in _inputValidators) {
        error = inputValidator(value);
        if (error != null && _errorText.value == null) {
          _errorText.value = t(error);
        }
        if (error != null) {
          valid = false;
        }
      }
      if (valid) {
        currentRawValue = value;
        _errorText.value = null;
      } else {
        _textEditingController.text = currentRawValue;
        _textEditingController.selection = TextSelection.collapsed(
          offset: currentRawValue.length,
        );
        if (_inputError != null) {
          _errorText.value = _inputError;
          _inputError = null;
        }
      }
    });
  }

  String? _inputError;

  bool validate() {
    bool valid = true;
    //print("Validating $fieldName ${_textEditingController.value.text}");
    for (var valueValidator in _valueValidators) {
      String? error = valueValidator(_textEditingController.value.text);
      if (error != null && _errorText.value == null) {
        _errorText.value = t(error);
      }
      if (error != null) {
        valid = false;
      }
    }
    if (valid) {
      _errorText.value = null;
    }
    return valid;
  }

  T save() {
    return super.set(_valueConverter(_textEditingController.value.text));
  }

  String? get errorText => _errorText.value;

  late TextEditingController _textEditingController;

  Widget getField() {
    final String labelText = t("$formName.$fieldName.label");
    final String helperText = t("$formName.$fieldName.helperText");
    return ValueListenableBuilder(
      builder: (context, value, widget) {
        return TextField(
          decoration: InputDecoration(
            label: Text(labelText),
            helperText: helperText,
            errorText: _errorText.value,
          ),
          controller: _textEditingController,
          obscureText: obscureText,
          //onChanged: _onChange,
        );
      },
      valueListenable: _errorText,
    );
  }

  String currentRawValue = "";
  final ValueNotifier<String?> _errorText = ValueNotifier(null);

  final List<String? Function(String)> _valueValidators = [];
  final List<String? Function(String)> _inputValidators = [];

  String Function(T) _valueToTextConverter = (T value) {
    return value.toString();
  };

  T Function(String) _valueConverter = (String value) {
    if (T == String) {
      return value as T;
    } else {
      throw Exception();
    }
  };

  void reset() {
    set(initialValue);
    String textValue = _valueToTextConverter(initialValue);
    _textEditingController.value = TextEditingValue(
      text: textValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: _valueToTextConverter(initialValue).length),
      ),
    );
  }

  @override
  T set(T value) {
    String textValue = _valueToTextConverter(value);
    _textEditingController.value = TextEditingValue(
      text: textValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: textValue.length),
      ),
    );
    return super.set(value);
  }
}

class TomEmailField<T> extends TomField<T> {
  TomEmailField(
    super.formName,
    super.fieldName,
    super.initialValue, {
    super.obscureText,
  }) {
    _valueValidators.add((value) {
      if (value.isEmpty) {
        return "$formName.$fieldName.errors.required";
      }
      if (!isValidEmail(value)) {
        return "$formName.$fieldName.errors.validEmail";
      }
      return null;
    });
  }

  static bool isValidEmail(String s) {
    return RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
    )
    //r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$")
    //r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
    .hasMatch(s);
  }
}

class TomPasswordField<T> extends TomField<T> {
  TomPasswordField(
    super.formName,
    super.fieldName,
    super.initialValue, {
    super.obscureText = true,
  }) {
    _valueValidators.add((value) {
      if (value.isEmpty) {
        return "$formName.$fieldName.errors.required";
      }
      if (value.length < 4) {
        return "$formName.$fieldName.errors.minimumLength";
      }
      return null;
    });
  }
}
